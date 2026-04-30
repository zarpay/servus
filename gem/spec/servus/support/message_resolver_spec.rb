# frozen_string_literal: true

RSpec.describe Servus::Support::MessageResolver do
  describe '#resolve' do
    context 'with string template' do
      it 'returns static string as-is' do
        resolver = described_class.new(template: 'Hello, World!')
        expect(resolver.resolve).to eq('Hello, World!')
      end

      it 'interpolates named placeholders' do
        resolver = described_class.new(
          template: 'Hello, %<name>s!',
          data: { name: 'Alice' }
        )
        expect(resolver.resolve).to eq('Hello, Alice!')
      end

      it 'interpolates multiple placeholders' do
        resolver = described_class.new(
          template: '%<greeting>s, %<name>s! You have %<count>d messages.',
          data: { greeting: 'Hello', name: 'Bob', count: 5 }
        )
        expect(resolver.resolve).to eq('Hello, Bob! You have 5 messages.')
      end

      it 'handles empty data gracefully' do
        resolver = described_class.new(template: 'No placeholders here')
        expect(resolver.resolve).to eq('No placeholders here')
      end
    end

    context 'with symbol template (I18n)' do
      context 'without I18n defined' do
        before do
          hide_const('I18n') if defined?(I18n)
        end

        it 'returns humanized symbol as fallback' do
          resolver = described_class.new(template: :insufficient_balance)
          expect(resolver.resolve).to eq('Insufficient balance')
        end

        it 'handles underscores in symbol' do
          resolver = described_class.new(template: :invalid_amount_error)
          expect(resolver.resolve).to eq('Invalid amount error')
        end
      end

      context 'with I18n defined' do
        before do
          stub_const('I18n', Class.new do
            def self.t(key, default:)
              if key == 'guards.insufficient_balance'
                'Balance is too low'
              else
                default
              end
            end

            def self.locale
              :en
            end
          end)
        end

        it 'looks up key with scope prefix' do
          resolver = described_class.new(
            template: :insufficient_balance,
            i18n_scope: 'guards'
          )
          expect(resolver.resolve).to eq('Balance is too low')
        end

        it 'falls back to humanized symbol when translation missing' do
          resolver = described_class.new(
            template: :unknown_key,
            i18n_scope: 'guards'
          )
          expect(resolver.resolve).to eq('Unknown key')
        end

        it 'uses full key when it contains a dot' do
          resolver = described_class.new(template: :'errors.custom.message')
          expect(resolver.resolve).to eq('Errors.custom.message')
        end
      end
    end

    context 'with hash template (inline translations)' do
      let(:template) do
        { en: 'Hello', es: 'Hola', fr: 'Bonjour' }
      end

      context 'without I18n defined' do
        before do
          hide_const('I18n') if defined?(I18n)
        end

        it 'defaults to :en locale' do
          resolver = described_class.new(template: template)
          expect(resolver.resolve).to eq('Hello')
        end

        it 'falls back to :en when current locale missing' do
          resolver = described_class.new(template: { de: 'Hallo', en: 'Hello' })
          expect(resolver.resolve).to eq('Hello')
        end

        it 'falls back to first value when :en missing' do
          resolver = described_class.new(template: { de: 'Hallo', fr: 'Bonjour' })
          expect(resolver.resolve).to eq('Hallo')
        end
      end

      context 'with I18n defined' do
        it 'uses current locale' do
          stub_const('I18n', Class.new do
            def self.locale
              :es
            end
          end)

          resolver = described_class.new(template: template)
          expect(resolver.resolve).to eq('Hola')
        end
      end
    end

    context 'with proc template' do
      it 'evaluates proc without context' do
        resolver = described_class.new(template: -> { 'Dynamic message' })
        expect(resolver.resolve).to eq('Dynamic message')
      end

      it 'evaluates proc in context' do
        context_object = Struct.new(:name).new('Charlie')
        resolver = described_class.new(template: -> { "Hello, #{name}!" })
        expect(resolver.resolve(context: context_object)).to eq('Hello, Charlie!')
      end

      it 'converts proc result to string' do
        resolver = described_class.new(template: -> { 42 })
        expect(resolver.resolve).to eq('42')
      end
    end

    context 'with nil template' do
      it 'returns empty string' do
        resolver = described_class.new(template: nil)
        expect(resolver.resolve).to eq('')
      end
    end

    context 'with data as proc' do
      it 'evaluates data proc without context' do
        resolver = described_class.new(
          template: 'Count: %<count>d',
          data: -> { { count: 10 } }
        )
        expect(resolver.resolve).to eq('Count: 10')
      end

      it 'evaluates data proc in context' do
        context_object = Struct.new(:items).new([1, 2, 3])
        resolver = described_class.new(
          template: 'Items: %<count>d',
          data: -> { { count: items.length } }
        )
        expect(resolver.resolve(context: context_object)).to eq('Items: 3')
      end
    end

    context 'error handling' do
      it 'returns template when interpolation fails due to missing key' do
        resolver = described_class.new(
          template: 'Hello, %<name>s!',
          data: { wrong_key: 'Alice' }
        )
        expect { resolver.resolve }.to output(/interpolation failed/).to_stderr
        expect(resolver.resolve).to eq('Hello, %<name>s!')
      end
    end
  end
end
