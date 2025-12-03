# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Servus::EventHandler do
  after do
    Servus::Events::Bus.clear
  end

  describe '.handles' do
    it 'declares the event this handler subscribes to' do
      handler_class = Class.new(described_class) do
        handles :user_created
      end

      expect(handler_class.event_name).to eq(:user_created)
    end

    it 'registers the handler with the Bus' do
      handler_class = Class.new(described_class) do
        handles :user_created
      end

      handlers = Servus::Events::Bus.handlers_for(:user_created)
      expect(handlers).to include(handler_class)
    end
  end

  describe '.invoke' do
    it 'declares a service invocation with payload mapping' do
      dummy_service = Class.new(Servus::Base)

      handler_class = Class.new(described_class) do
        handles :user_created

        invoke dummy_service do |payload|
          { user_id: payload[:user_id] }
        end
      end

      invocations = handler_class.invocations
      expect(invocations.size).to eq(1)
      expect(invocations.first[:service_class]).to eq(dummy_service)
      expect(invocations.first[:mapper]).to be_a(Proc)
    end

    it 'supports async option' do
      dummy_service = Class.new(Servus::Base)

      handler_class = Class.new(described_class) do
        handles :user_created

        invoke dummy_service, async: true do |payload|
          { user_id: payload[:user_id] }
        end
      end

      invocations = handler_class.invocations
      expect(invocations.first[:options][:async]).to be true
    end

    it 'supports conditional execution with :if option' do
      dummy_service = Class.new(Servus::Base)

      handler_class = Class.new(described_class) do
        handles :user_created

        invoke dummy_service, if: ->(payload) { payload[:premium] } do |payload|
          { user_id: payload[:user_id] }
        end
      end

      invocations = handler_class.invocations
      expect(invocations.first[:options][:if]).to be_a(Proc)
    end
  end

  describe '.handle' do
    it 'dispatches to the configured service' do
      dummy_service = Class.new(Servus::Base) do
        def self.call(**args)
          @called_with = args
          Servus::Support::Response.new(true, { result: 'success' }, nil)
        end

        class << self
          attr_reader :called_with
        end
      end

      handler_class = Class.new(described_class) do
        handles :user_created

        invoke dummy_service do |payload|
          { user_id: payload[:user_id] }
        end
      end

      handler_class.handle({ user_id: 123, email: 'test@example.com' })

      expect(dummy_service.called_with).to eq({ user_id: 123 })
    end

    it 'respects :if condition - invokes when true' do
      dummy_service = Class.new(Servus::Base) do
        def self.call(**_args)
          @call_count = 1
          Servus::Support::Response.new(true, nil, nil)
        end

        class << self
          attr_reader :call_count
        end
      end

      handler_class = Class.new(described_class) do
        handles :user_created

        invoke dummy_service, if: ->(payload) { payload[:premium] } do |payload|
          { user_id: payload[:user_id] }
        end
      end

      handler_class.handle({ user_id: 123, premium: true })

      expect(dummy_service.call_count).to eq(1)
    end

    it 'respects :if condition - skips when false' do
      dummy_service = Class.new(Servus::Base) do
        def self.call(**_args)
          @call_count = 1
          Servus::Support::Response.new(true, nil, nil)
        end

        class << self
          attr_reader :call_count
        end
      end

      handler_class = Class.new(described_class) do
        handles :user_created

        invoke dummy_service, if: ->(payload) { payload[:premium] } do |payload|
          { user_id: payload[:user_id] }
        end
      end

      handler_class.handle({ user_id: 123, premium: false })

      expect(dummy_service.call_count).to be_nil
    end

    it 'respects :unless condition - invokes when false' do
      dummy_service = Class.new(Servus::Base) do
        def self.call(**_args)
          @call_count = 1
          Servus::Support::Response.new(true, nil, nil)
        end

        class << self
          attr_reader :call_count
        end
      end

      handler_class = Class.new(described_class) do
        handles :user_created

        invoke dummy_service, unless: ->(payload) { payload[:spam] } do |payload|
          { user_id: payload[:user_id] }
        end
      end

      handler_class.handle({ user_id: 123, spam: false })

      expect(dummy_service.call_count).to eq(1)
    end

    it 'respects :unless condition - skips when true' do
      dummy_service = Class.new(Servus::Base) do
        def self.call(**_args)
          @call_count = 1
          Servus::Support::Response.new(true, nil, nil)
        end

        class << self
          attr_reader :call_count
        end
      end

      handler_class = Class.new(described_class) do
        handles :user_created

        invoke dummy_service, unless: ->(payload) { payload[:spam] } do |payload|
          { user_id: payload[:user_id] }
        end
      end

      handler_class.handle({ user_id: 123, spam: true })

      expect(dummy_service.call_count).to be_nil
    end

    it 'invokes multiple services in order' do
      calls = []

      service1 = Class.new(Servus::Base) do
        define_singleton_method(:call) do |**args|
          calls << [:service1, args]
          Servus::Support::Response.new(true, nil, nil)
        end
      end

      service2 = Class.new(Servus::Base) do
        define_singleton_method(:call) do |**args|
          calls << [:service2, args]
          Servus::Support::Response.new(true, nil, nil)
        end
      end

      handler_class = Class.new(described_class) do
        handles :user_created

        invoke service1 do |payload|
          { id: payload[:user_id] }
        end

        invoke service2 do |payload|
          { user: payload[:user_id] }
        end
      end

      handler_class.handle({ user_id: 123 })

      expect(calls).to eq([
                            [:service1, { id: 123 }],
                            [:service2, { user: 123 }]
                          ])
    end

    it 'invokes service asynchronously when async: true' do
      dummy_service = Class.new(Servus::Base) do
        def self.call_async(**args)
          @async_called_with = args
        end

        class << self
          attr_reader :async_called_with
        end
      end

      handler_class = Class.new(described_class) do
        handles :user_created

        invoke dummy_service, async: true do |payload|
          { user_id: payload[:user_id] }
        end
      end

      handler_class.handle({ user_id: 456 })

      expect(dummy_service.async_called_with).to eq({ user_id: 456 })
    end

    it 'passes queue option to call_async' do
      dummy_service = Class.new(Servus::Base) do
        def self.call_async(**args)
          @async_called_with = args
        end

        class << self
          attr_reader :async_called_with
        end
      end

      handler_class = Class.new(described_class) do
        handles :user_created

        invoke dummy_service, async: true, queue: :mailers do |payload|
          { user_id: payload[:user_id] }
        end
      end

      handler_class.handle({ user_id: 789 })

      expect(dummy_service.async_called_with).to eq({ user_id: 789, queue: :mailers })
    end
  end

  describe '.validate_all_handlers!' do
    after do
      Servus.config.strict_event_validation = true
    end

    it 'passes when all handlers have matching service emissions' do
      stub_const('TestService', Class.new(Servus::Base) do
        emits :user_created, on: :success

        def call
          success({})
        end
      end)

      stub_const('UserCreatedHandler', Class.new(described_class) do
        handles :user_created
      end)

      expect { described_class.validate_all_handlers! }.not_to raise_error
    end

    it 'raises error when handler subscribes to non-existent event' do
      stub_const('OrphanedHandler', Class.new(described_class) do
        handles :non_existent_event
      end)

      expect { described_class.validate_all_handlers! }
        .to raise_error(Servus::Events::OrphanedHandlerError, /OrphanedHandler.*:non_existent_event/)
    end

    it 'skips validation when config.strict_event_validation is false' do
      Servus.config.strict_event_validation = false

      stub_const('OrphanedHandler', Class.new(described_class) do
        handles :orphaned_event
      end)

      expect { described_class.validate_all_handlers! }.not_to raise_error
    end
  end

  describe '.emit' do
    it 'emits the event via the Bus' do
      handler_received_payload = nil

      handler_class = Class.new(described_class) do
        handles :user_created

        define_singleton_method(:handle) do |payload|
          handler_received_payload = payload
        end
      end

      handler_class.emit({ user_id: 123, email: 'test@example.com' })

      expect(handler_received_payload).to eq({ user_id: 123, email: 'test@example.com' })
    end

    it 'raises error if no event configured' do
      handler_class = Class.new(described_class)

      expect { handler_class.emit({ data: 'test' }) }
        .to raise_error(RuntimeError, /No event configured/)
    end
  end

  describe 'schema' do
    it 'defines payload schema for validation' do
      handler_class = Class.new(described_class) do
        handles :user_created

        schema payload: {
          type: 'object',
          required: ['user_id'],
          properties: {
            user_id: { type: 'integer' }
          }
        }
      end

      expect(handler_class.payload_schema).to include('type' => 'object')
      expect(handler_class.payload_schema['required']).to eq(['user_id'])
    end

    it 'validates payload when emitting' do
      handler_class = Class.new(described_class) do
        handles :user_created

        schema payload: {
          type: 'object',
          required: ['user_id'],
          properties: {
            user_id: { type: 'integer' }
          }
        }
      end

      expect { handler_class.emit({ user_id: 123 }) }.not_to raise_error
    end

    it 'raises ValidationError for invalid payload' do
      handler_class = Class.new(described_class) do
        handles :user_created

        schema payload: {
          type: 'object',
          required: ['user_id'],
          properties: {
            user_id: { type: 'integer' }
          }
        }
      end

      expect { handler_class.emit({ user_id: 'not-an-integer' }) }
        .to raise_error(Servus::Support::Errors::ValidationError, /user_id/)
    end
  end
end
