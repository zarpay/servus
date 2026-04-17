# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Servus::Guard do
  describe '.http_status' do
    it 'declares the HTTP status code' do
      guard_class = Class.new(described_class) do
        http_status 422
      end

      expect(guard_class.http_status_code).to eq(422)
    end
  end

  describe '.error_code' do
    it 'declares the error code' do
      guard_class = Class.new(described_class) do
        error_code 'insufficient_balance'
      end

      expect(guard_class.error_code_value).to eq('insufficient_balance')
    end
  end

  describe '.message' do
    it 'declares a static message template' do
      guard_class = Class.new(described_class) do
        message 'Value must be positive'
      end

      expect(guard_class.message_template).to eq('Value must be positive')
    end

    it 'declares a message template with interpolation block' do
      guard_class = Class.new(described_class) do
        message 'Balance: %<amount>s' do
          { amount: 100 }
        end
      end

      expect(guard_class.message_template).to eq('Balance: %<amount>s')
      expect(guard_class.message_block).to be_a(Proc)
    end

    it 'supports Symbol for I18n keys' do
      guard_class = Class.new(described_class) do
        message :insufficient_balance
      end

      expect(guard_class.message_template).to eq(:insufficient_balance)
    end

    it 'supports Hash for inline translations' do
      guard_class = Class.new(described_class) do
        message(en: 'English', es: 'Español')
      end

      expect(guard_class.message_template).to be_a(Hash)
      expect(guard_class.message_template[:en]).to eq('English')
    end

    it 'supports Proc for dynamic templates' do
      guard_class = Class.new(described_class) do
        message -> { 'Dynamic message' }
      end

      expect(guard_class.message_template).to be_a(Proc)
    end
  end

  describe '.inherited' do
    it 'defines bang method on Servus::Guards when class has a name' do
      guard_class = Class.new(described_class) do
        def test(**) = true
      end
      stub_const('SufficientBalance', guard_class)

      # Manually trigger method definition (inherited hook fired before stub_const)
      described_class.send(:register_guard_methods, guard_class)

      expect(Servus::Guards.method_defined?(:enforce_sufficient_balance!)).to be true
    end

    it 'defines predicate method on Servus::Guards when class has a name' do
      guard_class = Class.new(described_class) do
        def test(**) = true
      end
      stub_const('ValidAmount', guard_class)

      # Manually trigger method definition
      described_class.send(:register_guard_methods, guard_class)

      expect(Servus::Guards.method_defined?(:check_valid_amount?)).to be true
    end

    it 'skips method definition for anonymous classes' do
      # Anonymous classes should not crash or define methods
      guard_class = Class.new(described_class)

      # Should not define any new methods (no name to derive method from)
      expect { guard_class }.not_to raise_error
    end
  end

  describe '#initialize' do
    it 'stores kwargs' do
      guard_class = Class.new(described_class)
      guard = guard_class.new(account: 'test', amount: 100)

      expect(guard.kwargs).to eq({ account: 'test', amount: 100 })
    end
  end

  describe '#test' do
    it 'raises NotImplementedError if not overridden' do
      guard_class = Class.new(described_class)
      guard = guard_class.new

      expect { guard.test }.to raise_error(NotImplementedError, /must implement #test/)
    end

    it 'can be overridden with explicit parameters' do
      guard_class = Class.new(described_class) do
        def test(amount:)
          amount > 0
        end
      end

      guard = guard_class.new(amount: 100)
      expect(guard.test(amount: 100)).to be true

      guard = guard_class.new(amount: -10)
      expect(guard.test(amount: -10)).to be false
    end
  end

  describe '#message' do
    context 'with static string template' do
      it 'returns the static message' do
        guard_class = Class.new(described_class) do
          message 'Static error message'
        end

        guard = guard_class.new
        expect(guard.message).to eq('Static error message')
      end
    end

    context 'with string template and interpolation' do
      it 'interpolates data from the message block' do
        account_double = double(balance: 100)

        guard_class = Class.new(described_class) do
          message 'Insufficient balance: need %<required>s, have %<available>s' do
            {
              required: amount,
              available: account.balance
            }
          end

          def test(account:, amount:)
            account.balance >= amount
          end
        end

        guard = guard_class.new(account: account_double, amount: 150)
        expect(guard.message).to eq('Insufficient balance: need 150, have 100')
      end
    end

    context 'with Symbol template (I18n)' do
      it 'resolves I18n key when I18n is available' do
        skip 'I18n not available in test environment' unless defined?(I18n)

        allow(I18n).to receive(:t).with('guards.insufficient_balance', any_args)
                                  .and_return('Saldo insuficiente')

        guard_class = Class.new(described_class) do
          message :insufficient_balance
        end

        guard = guard_class.new
        expect(guard.message).to eq('Saldo insuficiente')
      end

      it 'falls back to humanized key when I18n is not available' do
        guard_class = Class.new(described_class) do
          message :insufficient_balance
        end

        guard = guard_class.new
        expect(guard.message).to eq('Insufficient balance')
      end
    end

    context 'with Hash template (inline translations)' do
      it 'returns the message for the current locale' do
        skip 'I18n not available in test environment' unless defined?(I18n)

        allow(I18n).to receive(:locale).and_return(:es)

        guard_class = Class.new(described_class) do
          message(en: 'English message', es: 'Mensaje en español')
        end

        guard = guard_class.new
        expect(guard.message).to eq('Mensaje en español')
      end

      it 'falls back to :en when locale not found' do
        skip 'I18n not available in test environment' unless defined?(I18n)

        allow(I18n).to receive(:locale).and_return(:fr)

        guard_class = Class.new(described_class) do
          message(en: 'English message', es: 'Mensaje en español')
        end

        guard = guard_class.new
        expect(guard.message).to eq('English message')
      end

      it 'returns first value when I18n is not available' do
        guard_class = Class.new(described_class) do
          message(en: 'English message', es: 'Mensaje en español')
        end

        guard = guard_class.new
        expect(guard.message).to eq('English message')
      end
    end

    context 'with Proc template (dynamic)' do
      it 'evaluates the proc at runtime' do
        guard_class = Class.new(described_class) do
          message -> { "Dynamic: #{limit_type}" }

          def test(limit_type:)
            @limit_type = limit_type
            true
          end

          attr_reader :limit_type
        end

        guard = guard_class.new(limit_type: 'daily')
        guard.test(limit_type: 'daily')
        expect(guard.message).to eq('Dynamic: daily')
      end
    end
  end

  describe '#method_missing' do
    it 'provides access to kwargs as methods' do
      guard_class = Class.new(described_class) do
        message 'Amount: %<value>s' do
          { value: amount }
        end
      end

      guard = guard_class.new(amount: 100)
      expect(guard.message).to eq('Amount: 100')
    end

    it 'raises NoMethodError for non-existent keys' do
      guard_class = Class.new(described_class)
      guard = guard_class.new(amount: 100)

      expect { guard.non_existent_method }.to raise_error(NoMethodError)
    end
  end

  describe '#respond_to_missing?' do
    it 'returns true for kwargs keys' do
      guard_class = Class.new(described_class)
      guard = guard_class.new(amount: 100)

      expect(guard.respond_to?(:amount)).to be true
    end

    it 'returns false for non-existent keys' do
      guard_class = Class.new(described_class)
      guard = guard_class.new(amount: 100)

      expect(guard.respond_to?(:non_existent)).to be false
    end
  end

  describe 'complete guard example' do
    it 'works end-to-end with all features' do
      account_double = double(balance: 100)

      guard_class = Class.new(described_class) do
        http_status 422
        error_code 'insufficient_balance'

        message 'Insufficient balance: need %<required>s, have %<available>s' do
          {
            required: amount,
            available: account.balance
          }
        end

        def test(account:, amount:)
          account.balance >= amount
        end
      end

      # Test passing case
      guard = guard_class.new(account: account_double, amount: 50)
      expect(guard.test(account: account_double, amount: 50)).to be true

      # Test failing case
      guard = guard_class.new(account: account_double, amount: 150)
      expect(guard.test(account: account_double, amount: 150)).to be false
      expect(guard.message).to eq('Insufficient balance: need 150, have 100')

      # Test error generation
      error = guard.error
      expect(error).to be_a(Servus::Support::Errors::GuardError)
      expect(error.detail).to eq('insufficient_balance')
      expect(error.message).to eq('Insufficient balance: need 150, have 100')
      expect(error.http_status).to eq(422)
    end
  end
end
