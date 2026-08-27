# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Servus Testing Matchers' do
  after do
    Servus::Events::Bus.clear
  end

  describe 'emit_event matcher' do
    it 'passes when event is emitted with matching payload' do
      service_class = stub_const('TestService', Class.new(Servus::Base) do
        emits :user_created, on: :success

        def call
          success({ user_id: 123, email: 'test@example.com' })
        end
      end)

      expect { service_class.call }.to emit_event(:user_created).with(hash_including(user_id: 123))
    end

    it 'fails when event is not emitted' do
      service_class = stub_const('TestService', Class.new(Servus::Base) do
        def call
          success({})
        end
      end)

      expect do
        expect { service_class.call }.to emit_event(:user_created)
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /expected.*:user_created.*to be emitted/)
    end

    it 'fails when payload does not match' do
      service_class = stub_const('TestService', Class.new(Servus::Base) do
        emits :user_created, on: :success

        def call
          success({ user_id: 999 })
        end
      end)

      expect do
        expect { service_class.call }.to emit_event(:user_created).with(hash_including(user_id: 123))
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError)
    end
  end

  describe 'call_service matcher' do
    it 'passes when service is called with matching arguments' do
      service_class = Class.new(Servus::Base) do
        def self.call(**args)
          Servus::Support::Response.new(true, args, nil)
        end
      end

      expect { service_class.call(user_id: 123) }.to call_service(service_class).with(user_id: 123)
    end

    it 'passes when async service is called' do
      service_class = Class.new(Servus::Base) do
        def self.call_async(**args)
          { args: args }
        end
      end

      expect { service_class.call_async(user_id: 456) }.to call_service(service_class).with(user_id: 456).async
    end
  end

  describe 'have_schema matcher' do
    before { Servus::Support::Validator.clear_cache! }

    it 'passes when arguments schema is defined' do
      service_class = stub_const('SchemaTestService', Class.new(Servus::Base) do
        schema arguments: { type: 'object', properties: { id: { type: 'integer' } } }

        def initialize(id:); end
        def call = success({})
      end)

      expect(service_class).to have_schema(:arguments)
    end

    it 'fails when no arguments schema is defined' do
      service_class = stub_const('NoSchemaTestService', Class.new(Servus::Base) do
        def initialize(id:); end
        def call = success({})
      end)

      expect(service_class).not_to have_schema(:arguments)
    end

    it 'works with result schemas' do
      service_class = stub_const('ResultSchemaTestService', Class.new(Servus::Base) do
        schema result: { type: 'object', properties: { id: { type: 'integer' } } }

        def initialize(id:); end
        def call = success({})
      end)

      expect(service_class).to have_schema(:result)
      expect(service_class).not_to have_schema(:arguments)
    end

    it 'works with payload schemas on event handlers' do
      handler_class = Class.new(Servus::Event) do
        event_name :test_schema_event

        schema payload: {
          type: 'object',
          properties: { user_id: { type: 'integer' } }
        }
      end

      expect(handler_class).to have_schema(:payload)
    end

    it 'fails when no payload schema is defined on event handler' do
      handler_class = Class.new(Servus::Event) do
        event_name :test_no_schema_event
      end

      expect(handler_class).not_to have_schema(:payload)
    end

    # The matcher used to clear the global schema cache on every invocation,
    # which discarded cache state belonging to every other example.
    it 'leaves the schema cache alone' do
      service_class = stub_const('CachePreservedService', Class.new(Servus::Base) do
        schema arguments: { type: 'object' }
      end)
      Servus::Support::Validator.load_schema(service_class, 'arguments')

      expect { expect(service_class).to have_schema(:arguments) }
        .not_to(change { Servus::Support::Validator.cache.size })
    end

    it 'fails loudly when a schema references an unregistered fragment' do
      service_class = stub_const('BrokenRefService', Class.new(Servus::Base) do
        schema arguments: { '$ref' => '#/nope/$defs/thing' }
      end)

      expect { expect(service_class).to have_schema(:arguments) }
        .to raise_error(Servus::Schema::UnknownKeyError)
    end
  end

  describe 'be_service_success matcher' do
    it 'passes for a successful response' do
      result = Servus::Support::Response.new(true, { id: 1 }, nil)

      expect(result).to be_service_success
    end

    it 'fails for a failure response' do
      error = Servus::Support::Errors::ServiceError.new('fail')
      result = Servus::Support::Response.new(false, nil, error)

      expect do
        expect(result).to be_service_success
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /expected a successful response/)
    end

    it 'fails for non-Response objects' do
      expect do
        expect('not a response').to be_service_success
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /expected a Servus::Support::Response/)
    end
  end

  describe 'be_service_failure matcher' do
    it 'passes for any failure response without arguments' do
      error = Servus::Support::Errors::ServiceError.new('fail')
      result = Servus::Support::Response.new(false, nil, error)

      expect(result).to be_service_failure
    end

    it 'passes when error class matches' do
      error = Servus::Support::Errors::NotFoundError.new('missing')
      result = Servus::Support::Response.new(false, nil, error)

      expect(result).to be_service_failure(Servus::Support::Errors::NotFoundError)
    end

    it 'fails when error class does not match' do
      error = Servus::Support::Errors::ServiceError.new('fail')
      result = Servus::Support::Response.new(false, nil, error)

      expect do
        expect(result).to be_service_failure(Servus::Support::Errors::NotFoundError)
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /expected error to be a/)
    end

    it 'fails for a success response' do
      result = Servus::Support::Response.new(true, {}, nil)

      expect do
        expect(result).to be_service_failure
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /expected a failure response/)
    end

    it 'supports with_message chain' do
      error = Servus::Support::Errors::NotFoundError.new('User not found')
      result = Servus::Support::Response.new(false, nil, error)

      expect(result).to be_service_failure(Servus::Support::Errors::NotFoundError).with_message('User not found')
    end

    it 'fails when message does not match' do
      error = Servus::Support::Errors::NotFoundError.new('User not found')
      result = Servus::Support::Response.new(false, nil, error)

      expect do
        expect(result).to be_service_failure.with_message('Wrong message')
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /expected error message/)
    end
  end

  describe 'be_guard_failure matcher' do
    it 'passes for guard failure without code' do
      error = Servus::Support::Errors::GuardError.new('fail', code: 'test_code')
      result = Servus::Support::Response.new(false, nil, error)

      expect(result).to be_guard_failure
    end

    it 'passes when guard error code matches' do
      error = Servus::Support::Errors::GuardError.new('fail', code: 'insufficient_balance')
      result = Servus::Support::Response.new(false, nil, error)

      expect(result).to be_guard_failure('insufficient_balance')
    end

    it 'fails when code does not match' do
      error = Servus::Support::Errors::GuardError.new('fail', code: 'wrong_code')
      result = Servus::Support::Response.new(false, nil, error)

      expect do
        expect(result).to be_guard_failure('insufficient_balance')
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /expected guard error code/)
    end

    it 'fails when error is not a GuardError' do
      error = Servus::Support::Errors::ServiceError.new('fail')
      result = Servus::Support::Response.new(false, nil, error)

      expect do
        expect(result).to be_guard_failure
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /expected error to be a GuardError/)
    end

    it 'supports with_message chain' do
      error = Servus::Support::Errors::GuardError.new('Balance too low', code: 'insufficient_balance')
      result = Servus::Support::Response.new(false, nil, error)

      expect(result).to be_guard_failure('insufficient_balance').with_message('Balance too low')
    end
  end
end
