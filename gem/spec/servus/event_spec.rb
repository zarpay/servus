# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Servus::Event do
  after do
    Servus::Events::Bus.clear
  end

  describe '.event_name' do
    it 'declares the event name and subscribes to the Bus' do
      event_class = Class.new(described_class) do
        event_name :user_created
      end

      expect(event_class.event_name).to eq(:user_created)
      expect(Servus::Events::Bus.event_for(:user_created)).to eq(event_class)
    end

    it 'raises if called twice' do
      expect {
        Class.new(described_class) do
          event_name :first
          event_name :second
        end
      }.to raise_error(RuntimeError, /already subscribed/)
    end

    it 'infers the name from a named class' do
      stub_const('OrderPlaced', Class.new(described_class))
      OrderPlaced.ensure_registered!

      expect(OrderPlaced.event_name).to eq(:order_placed)
    end

    it 'strips module namespacing via demodulize' do
      stub_const('Events::OrderPlaced', Class.new(described_class))
      Events::OrderPlaced.ensure_registered!

      expect(Events::OrderPlaced.event_name).to eq(:order_placed)
    end

    it 'does not override an explicit event name' do
      event_class = Class.new(described_class) do
        event_name :custom_name
      end
      event_class.ensure_registered!

      expect(event_class.event_name).to eq(:custom_name)
    end

    it 'returns nil for anonymous classes' do
      event_class = Class.new(described_class)
      event_class.ensure_registered!

      expect(event_class.event_name).to be_nil
    end
  end

  describe '.invoke' do
    it 'declares a service invocation with payload mapping' do
      dummy_service = Class.new(Servus::Base)

      event_class = Class.new(described_class) do
        event_name :user_created

        invoke dummy_service do |payload|
          { user_id: payload[:user_id] }
        end
      end

      invocations = event_class.invocations
      expect(invocations.size).to eq(1)
      expect(invocations.first[:service_class]).to eq(dummy_service)
      expect(invocations.first[:mapper]).to be_a(Proc)
    end

    it 'passes the full payload when no block is given' do
      dummy_service = Class.new(Servus::Base) do
        def self.call(**args)
          @called_with = args
          Servus::Support::Response.new(true, args, nil)
        end

        class << self
          attr_reader :called_with
        end
      end

      event_class = Class.new(described_class) do
        event_name :user_created

        invoke dummy_service
      end

      event_class.handle({ user_id: 123, email: 'test@example.com' })

      expect(dummy_service.called_with).to eq({ user_id: 123, email: 'test@example.com' })
    end

    it 'supports async option' do
      dummy_service = Class.new(Servus::Base)

      event_class = Class.new(described_class) do
        event_name :user_created

        invoke dummy_service, async: true do |payload|
          { user_id: payload[:user_id] }
        end
      end

      invocations = event_class.invocations
      expect(invocations.first[:options][:async]).to be true
    end

    it 'supports conditional execution with :if option' do
      dummy_service = Class.new(Servus::Base)

      event_class = Class.new(described_class) do
        event_name :user_created

        invoke dummy_service, if: ->(payload) { payload[:premium] } do |payload|
          { user_id: payload[:user_id] }
        end
      end

      invocations = event_class.invocations
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

      event_class = Class.new(described_class) do
        event_name :user_created

        invoke dummy_service do |payload|
          { user_id: payload[:user_id] }
        end
      end

      event_class.handle({ user_id: 123, email: 'test@example.com' })

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

      event_class = Class.new(described_class) do
        event_name :user_created

        invoke dummy_service, if: ->(payload) { payload[:premium] } do |payload|
          { user_id: payload[:user_id] }
        end
      end

      event_class.handle({ user_id: 123, premium: true })

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

      event_class = Class.new(described_class) do
        event_name :user_created

        invoke dummy_service, if: ->(payload) { payload[:premium] } do |payload|
          { user_id: payload[:user_id] }
        end
      end

      event_class.handle({ user_id: 123, premium: false })

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

      event_class = Class.new(described_class) do
        event_name :user_created

        invoke dummy_service, unless: ->(payload) { payload[:spam] } do |payload|
          { user_id: payload[:user_id] }
        end
      end

      event_class.handle({ user_id: 123, spam: false })

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

      event_class = Class.new(described_class) do
        event_name :user_created

        invoke dummy_service, unless: ->(payload) { payload[:spam] } do |payload|
          { user_id: payload[:user_id] }
        end
      end

      event_class.handle({ user_id: 123, spam: true })

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

      event_class = Class.new(described_class) do
        event_name :user_created

        invoke service1 do |payload|
          { id: payload[:user_id] }
        end

        invoke service2 do |payload|
          { user: payload[:user_id] }
        end
      end

      event_class.handle({ user_id: 123 })

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

      event_class = Class.new(described_class) do
        event_name :user_created

        invoke dummy_service, async: true do |payload|
          { user_id: payload[:user_id] }
        end
      end

      event_class.handle({ user_id: 456 })

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

      event_class = Class.new(described_class) do
        event_name :user_created

        invoke dummy_service, async: true, queue: :mailers do |payload|
          { user_id: payload[:user_id] }
        end
      end

      event_class.handle({ user_id: 789 })

      expect(dummy_service.async_called_with).to eq({ user_id: 789, queue: :mailers })
    end

    it 'passes multiple scheduling options to call_async' do
      dummy_service = Class.new(Servus::Base) do
        def self.call_async(**args)
          @async_called_with = args
        end

        class << self
          attr_reader :async_called_with
        end
      end

      event_class = Class.new(described_class) do
        event_name :user_created

        invoke dummy_service, async: true, queue: :critical, wait: 10.minutes, priority: 5 do |payload|
          { user_id: payload[:user_id] }
        end
      end

      event_class.handle({ user_id: 123 })

      expect(dummy_service.async_called_with).to eq({
        user_id: 123,
        queue: :critical,
        wait: 10.minutes,
        priority: 5
      })
    end
  end

  describe '.invocations_for' do
    it 'returns Invocation objects for the given payload' do
      dummy_service = Class.new(Servus::Base)

      event_class = Class.new(described_class) do
        event_name :user_created

        invoke dummy_service do |payload|
          { user_id: payload[:user_id] }
        end
      end

      invocations = event_class.invocations_for({ user_id: 42 })

      expect(invocations.length).to eq(1)
      expect(invocations.first).to be_a(Servus::Events::Invocation)
      expect(invocations.first.service).to eq(dummy_service)
      expect(invocations.first.params).to eq({ user_id: 42 })
    end

    it 'filters out invocations that fail the if condition' do
      dummy_service = Class.new(Servus::Base)

      event_class = Class.new(described_class) do
        event_name :user_created

        invoke dummy_service, if: ->(p) { p[:premium] } do |payload|
          { user_id: payload[:user_id] }
        end
      end

      expect(event_class.invocations_for({ user_id: 1, premium: false })).to be_empty
      expect(event_class.invocations_for({ user_id: 1, premium: true }).length).to eq(1)
    end

    it 'passes async options through to the Invocation' do
      dummy_service = Class.new(Servus::Base)

      event_class = Class.new(described_class) do
        event_name :user_created

        invoke dummy_service, async: true, queue: :mailers do |payload|
          { user_id: payload[:user_id] }
        end
      end

      invocation = event_class.invocations_for({ user_id: 1 }).first
      expect(invocation.options[:async]).to be true
      expect(invocation.options[:queue]).to eq(:mailers)
    end

    it 'excludes if/unless from the Invocation options' do
      dummy_service = Class.new(Servus::Base)

      event_class = Class.new(described_class) do
        event_name :user_created

        invoke dummy_service, async: true, if: ->(_p) { true } do |payload|
          { user_id: payload[:user_id] }
        end
      end

      invocation = event_class.invocations_for({ user_id: 1 }).first
      expect(invocation.options).not_to have_key(:if)
      expect(invocation.options).not_to have_key(:unless)
    end
  end

  describe '.emit' do
    it 'emits the event via the Bus' do
      event_class = Class.new(described_class) do
        event_name :emit_test_event
      end

      expect { event_class.emit({ user_id: 123 }) }
        .to emit_event(:emit_test_event)
        .with(hash_including(user_id: 123))
    end

    it 'raises if no event name configured' do
      event_class = Class.new(described_class)

      expect { event_class.emit({ data: 'test' }) }
        .to raise_error(RuntimeError, /No event configured/)
    end
  end

  describe '.schema' do
    it 'defines payload schema for validation' do
      event_class = Class.new(described_class) do
        event_name :user_created

        schema payload: {
          type: 'object',
          required: ['user_id'],
          properties: {
            user_id: { type: 'integer' }
          }
        }
      end

      expect(event_class.payload_schema).to include('type' => 'object')
      expect(event_class.payload_schema['required']).to eq(['user_id'])
    end

    it 'validates payload when emitting' do
      event_class = Class.new(described_class) do
        event_name :user_created

        schema payload: {
          type: 'object',
          required: ['user_id'],
          properties: {
            user_id: { type: 'integer' }
          }
        }
      end

      expect { event_class.emit({ user_id: 123 }) }.not_to raise_error
    end

    it 'raises ValidationError for invalid payload' do
      event_class = Class.new(described_class) do
        event_name :user_created

        schema payload: {
          type: 'object',
          required: ['user_id'],
          properties: {
            user_id: { type: 'integer' }
          }
        }
      end

      expect { event_class.emit({ user_id: 'not-an-integer' }) }
        .to raise_error(Servus::Support::Errors::ValidationError, /user_id/)
    end
  end
end
