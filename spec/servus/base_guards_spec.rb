# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Servus::Base, 'Guards Integration' do
  let(:user_class) do
    Struct.new(:active, :banned, :status, keyword_init: true) do
      def self.name
        'User'
      end
    end
  end

  describe 'guard methods' do
    it 'provides guard methods via method_missing' do
      test_class = user_class
      service_class = stub_const('GuardTestService1', Class.new(described_class) do
        define_method(:initialize) { |user:| @user = user }
        define_method(:test_class) { test_class }

        def call
          enforce_truthy!(on: @user, check: :active)
          success({ result: 'processed' })
        end
      end)

      result = service_class.call(user: test_class.new(active: true))
      expect(result.success?).to be true
      expect(result.data).to eq({ result: 'processed' })
    end

    it 'stops execution when guard fails' do
      test_class = user_class
      service_class = stub_const('GuardTestService2', Class.new(described_class) do
        define_method(:initialize) { |user:| @user = user }

        def call
          enforce_truthy!(on: @user, check: :active)
          success({ result: 'processed' })
        end
      end)

      result = service_class.call(user: test_class.new(active: false))
      expect(result.success?).to be false
      expect(result.error.message).to include('must be truthy')
    end

    it 'works with multiple guards' do
      test_class = user_class
      service_class = stub_const('GuardTestService3', Class.new(described_class) do
        define_method(:initialize) do |name:, user:|
          @name = name
          @user = user
        end

        def call
          enforce_presence!(name: @name)
          enforce_truthy!(on: @user, check: :active)
          success({ result: 'processed' })
        end
      end)

      # All guards pass
      result = service_class.call(name: 'user123', user: test_class.new(active: true))
      expect(result.success?).to be true

      # First guard fails
      result = service_class.call(name: nil, user: test_class.new(active: true))
      expect(result.success?).to be false
      expect(result.error.message).to include('must be present')

      # Second guard fails
      result = service_class.call(name: 'user123', user: test_class.new(active: false))
      expect(result.success?).to be false
      expect(result.error.message).to include('must be truthy')
    end

    it 'works in nested private methods' do
      test_class = user_class
      service_class = stub_const('GuardTestService4', Class.new(described_class) do
        define_method(:initialize) do |name:, user:|
          @name = name
          @user = user
        end

        def call
          validate_inputs
          success({ result: 'processed' })
        end

        private

        def validate_inputs
          enforce_presence!(name: @name)
          enforce_falsey!(on: @user, check: :banned)
        end
      end)

      # Guards pass
      result = service_class.call(name: 'user123', user: test_class.new(banned: false))
      expect(result.success?).to be true

      # Guard fails in nested method
      result = service_class.call(name: nil, user: test_class.new(banned: false))
      expect(result.success?).to be false
      expect(result.error.message).to include('must be present')
    end

    it 'works in deeply nested methods' do
      test_class = user_class
      service_class = stub_const('GuardTestService5', Class.new(described_class) do
        define_method(:initialize) do |name:, user:|
          @name = name
          @user = user
        end

        def call
          level1
          success({ result: 'processed' })
        end

        private

        def level1
          level2
        end

        def level2
          level3
        end

        def level3
          enforce_presence!(name: @name)
          enforce_state!(on: @user, check: :status, is: :active)
        end
      end)

      # Guards pass
      result = service_class.call(name: 'user123', user: test_class.new(status: :active))
      expect(result.success?).to be true

      # Guard fails in deeply nested method
      result = service_class.call(name: 'user123', user: test_class.new(status: :suspended))
      expect(result.success?).to be false
      expect(result.error.message).to include('must be active')
    end

    it 'raises NoMethodError for non-existent guard' do
      service_class = stub_const('GuardTestService6', Class.new(described_class) do
        def call
          ensure_non_existent!(value: 123)
          success({})
        end
      end)

      expect { service_class.call }.to raise_error(NoMethodError, /ensure_non_existent!/)
    end
  end

  describe 'backward compatibility with raise' do
    it 'still works with traditional raise approach' do
      test_class = user_class
      service_class = stub_const('GuardTestService7', Class.new(described_class) do
        define_method(:initialize) { |user:| @user = user }

        def call
          raise Servus::Support::Errors::ServiceError, 'User must be active' unless @user.active

          success({ result: 'processed' })
        end
      end)

      # Success case
      result = service_class.call(user: test_class.new(active: true))
      expect(result.success?).to be true

      # Failure case - raise still works
      expect { service_class.call(user: test_class.new(active: false)) }
        .to raise_error(Servus::Support::Errors::ServiceError, 'User must be active')
    end

    it 'can mix guards and raises' do
      test_class = user_class
      service_class = stub_const('GuardTestService8', Class.new(described_class) do
        define_method(:initialize) do |name:, user:|
          @name = name
          @user = user
        end

        def call
          # Use guard for validation
          enforce_presence!(name: @name)

          # Use raise for exceptional error
          raise Servus::Support::Errors::ServiceError, 'System unavailable' if system_down?

          # Use guard for business rule
          enforce_truthy!(on: @user, check: :active)

          success({ result: 'processed' })
        end

        private

        def system_down?
          false
        end
      end)

      result = service_class.call(name: 'user123', user: test_class.new(active: true))
      expect(result.success?).to be true

      # Guard failure returns failure response
      result = service_class.call(name: nil, user: test_class.new(active: true))
      expect(result.success?).to be false
      expect(result.error.message).to include('must be present')
    end
  end

  describe 'respond_to?' do
    it 'returns true for registered guard methods' do
      service_class = stub_const('GuardTestService9', Class.new(described_class) do
        def call
          success({})
        end
      end)

      instance = service_class.new
      expect(instance.respond_to?(:enforce_presence!)).to be true
      expect(instance.respond_to?(:enforce_truthy!)).to be true
      expect(instance.respond_to?(:enforce_falsey!)).to be true
      expect(instance.respond_to?(:enforce_state!)).to be true
    end

    it 'returns false for non-existent guard methods' do
      service_class = stub_const('GuardTestService10', Class.new(described_class) do
        def call
          success({})
        end
      end)

      instance = service_class.new
      expect(instance.respond_to?(:ensure_non_existent!)).to be false
    end
  end

  describe 'error response structure' do
    it 'returns proper failure response with guard metadata' do
      test_class = user_class
      service_class = stub_const('GuardTestService11', Class.new(described_class) do
        define_method(:initialize) { |user:| @user = user }

        def call
          enforce_truthy!(on: @user, check: :active)
          success({ result: 'processed' })
        end
      end)

      result = service_class.call(user: test_class.new(active: false))

      expect(result.success?).to be false
      expect(result.error).to be_a(Servus::Support::Errors::ServiceError)
      expect(result.error.message).to eq('User.active must be truthy (got false)')
    end
  end

  describe 'predicate guard methods' do
    it 'returns true when guard passes' do
      test_class = user_class
      service_class = stub_const('GuardTestService12', Class.new(described_class) do
        define_method(:initialize) { |user:| @user = user }

        def call
          if check_truthy?(on: @user, check: :active)
            success({ validated: true })
          else
            success({ validated: false })
          end
        end
      end)

      result = service_class.call(user: test_class.new(active: true))
      expect(result.success?).to be true
      expect(result.data[:validated]).to be true
    end

    it 'returns false when guard fails without throwing' do
      test_class = user_class
      service_class = stub_const('GuardTestService13', Class.new(described_class) do
        define_method(:initialize) { |user:| @user = user }

        def call
          if check_truthy?(on: @user, check: :active)
            success({ validated: true })
          else
            success({ validated: false })
          end
        end
      end)

      result = service_class.call(user: test_class.new(active: false))
      expect(result.success?).to be true
      expect(result.data[:validated]).to be false
    end
  end

  describe 'guard failure logging' do
    it 'logs guard failures at warn level' do
      test_class = user_class
      service_class = stub_const('GuardLogTestService', Class.new(described_class) do
        define_method(:initialize) { |user:| @user = user }

        def call
          enforce_truthy!(on: @user, check: :active)
          success({ result: 'processed' })
        end
      end)

      allow(Servus::Support::Logger).to receive(:log_guard_failure)

      service_class.call(user: test_class.new(active: false))

      expect(Servus::Support::Logger).to have_received(:log_guard_failure)
        .with(GuardLogTestService, an_instance_of(Servus::Support::Errors::GuardError))
    end

    it 'does not log when guard passes' do
      test_class = user_class
      service_class = stub_const('GuardLogTestService2', Class.new(described_class) do
        define_method(:initialize) { |user:| @user = user }

        def call
          enforce_truthy!(on: @user, check: :active)
          success({ result: 'processed' })
        end
      end)

      allow(Servus::Support::Logger).to receive(:log_guard_failure)

      service_class.call(user: test_class.new(active: true))

      expect(Servus::Support::Logger).not_to have_received(:log_guard_failure)
    end
  end

  describe 'state guard with multiple values' do
    it 'passes when attribute matches any expected value' do
      test_class = user_class
      service_class = stub_const('GuardTestService14', Class.new(described_class) do
        define_method(:initialize) { |user:| @user = user }

        def call
          enforce_state!(on: @user, check: :status, is: %i[active trial])
          success({ result: 'processed' })
        end
      end)

      result = service_class.call(user: test_class.new(status: :trial))
      expect(result.success?).to be true
    end

    it 'fails when attribute matches none of expected values' do
      test_class = user_class
      service_class = stub_const('GuardTestService15', Class.new(described_class) do
        define_method(:initialize) { |user:| @user = user }

        def call
          enforce_state!(on: @user, check: :status, is: %i[active trial])
          success({ result: 'processed' })
        end
      end)

      result = service_class.call(user: test_class.new(status: :suspended))
      expect(result.success?).to be false
      expect(result.error.message).to include('one of')
    end
  end
end
