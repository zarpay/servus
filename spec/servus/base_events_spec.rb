# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Servus::Base, 'event emission' do
  after do
    Servus::Events::Bus.clear
  end

  describe '.emits' do
    it 'declares an event to emit on success' do
      service_class = Class.new(Servus::Base) do
        emits :user_created, on: :success

        def call
          success({ user_id: 123 })
        end
      end

      emissions = service_class.event_emissions[:success]
      expect(emissions).to include(
        hash_including(event_name: :user_created)
      )
    end

    it 'declares an event to emit on failure' do
      service_class = Class.new(Servus::Base) do
        emits :user_failed, on: :failure

        def call
          failure
        end
      end

      emissions = service_class.event_emissions[:failure]
      expect(emissions).to include(
        hash_including(event_name: :user_failed)
      )
    end

    it 'declares an event to emit on error! (only explicit error)' do
      service_class = Class.new(Servus::Base) do
        emits :user_error, on: :error!

        def call
          error!('Something really bad happened')
        end
      end

      emissions = service_class.event_emissions[:error!]
      expect(emissions).to include(
        hash_including(event_name: :user_error)
      )
    end

    it 'supports custom payload builder with :with option' do
      service_class = Class.new(Servus::Base) do
        emits :user_created, on: :success, with: :custom_payload

        def call
          success({ user_id: 123 })
        end

        private

        def custom_payload(result)
          { id: result.data[:user_id] }
        end
      end

      emissions = service_class.event_emissions[:success]
      expect(emissions).to include(
        hash_including(
          event_name: :user_created,
          payload_builder: :custom_payload
        )
      )
    end

    it 'supports custom payload builder with block' do
      service_class = Class.new(Servus::Base) do
        emits :user_created, on: :success do |result|
          { id: result.data[:user_id] }
        end

        def call
          success({ user_id: 123 })
        end

        private

        def custom_payload(result)
          { id: result.data[:user_id] }
        end
      end

      emissions = service_class.event_emissions[:success]
      expect(emissions).to include(
        hash_including(
          event_name: :user_created,
          payload_builder: a_kind_of(Proc)
        )
      )
    end
  end

  describe 'automatic event emission' do
    it 'emits events on success' do
      handler_class = Class.new do
        def self.handle(payload)
          @received_payload = payload
        end

        class << self
          attr_reader :received_payload
        end
      end

      Servus::Events::Bus.register_handler(:user_created, handler_class)

      service_class = stub_const('TestEventEmissionService', Class.new(Servus::Base) do
        emits :user_created, on: :success

        def initialize(user_id:)
          @user_id = user_id
        end

        def call
          success({ user_id: @user_id, email: 'test@example.com' })
        end
      end)

      service_class.call(user_id: 123)

      expect(handler_class.received_payload).to eq({ user_id: 123, email: 'test@example.com' })
    end

    it 'emits events on failure' do
      handler_class = Class.new do
        def self.handle(payload)
          @received_payload = payload
        end

        class << self
          attr_reader :received_payload
        end
      end

      Servus::Events::Bus.register_handler(:user_failed, handler_class)

      service_class = stub_const('TestFailureService', Class.new(Servus::Base) do
        emits :user_failed, on: :failure

        def call
          failure('User not found')
        end
      end)

      service_class.call

      expect(handler_class.received_payload).to be_an_instance_of(Servus::Support::Errors::ServiceError)
    end

    it 'emits events with custom payload builder' do
      handler_class = Class.new do
        def self.handle(payload)
          @received_payload = payload
        end

        class << self
          attr_reader :received_payload
        end
      end

      Servus::Events::Bus.register_handler(:user_created, handler_class)

      service_class = stub_const('TestCustomPayloadService', Class.new(Servus::Base) do
        emits :user_created, on: :success, with: :custom_payload

        def initialize(user_id:)
          @user_id = user_id
        end

        def call
          success({ user_id: @user_id, email: 'test@example.com' })
        end

        private

        def custom_payload(result)
          { id: result.data[:user_id] }
        end
      end)

      service_class.call(user_id: 456)

      expect(handler_class.received_payload).to eq({ id: 456 })
    end

    it 'emits multiple events for the same trigger' do
      handler1 = Class.new do
        def self.handle(payload)
          @received = payload
        end

        class << self
          attr_accessor :received
        end
      end

      handler2 = Class.new do
        def self.handle(payload)
          @received = payload
        end

        class << self
          attr_accessor :received
        end
      end

      Servus::Events::Bus.register_handler(:event_one, handler1)
      Servus::Events::Bus.register_handler(:event_two, handler2)

      service_class = stub_const('TestMultipleEventsService', Class.new(Servus::Base) do
        emits :event_one, on: :success
        emits :event_two, on: :success

        def call
          success({ data: 'test' })
        end
      end)

      service_class.call

      expect(handler1.received).to eq({ data: 'test' })
      expect(handler2.received).to eq({ data: 'test' })
    end

    it 'emits events on explicit error!' do
      handler_class = Class.new do
        def self.handle(payload)
          @received_payload = payload
        end

        class << self
          attr_reader :received_payload
        end
      end

      Servus::Events::Bus.register_handler(:critical_error, handler_class)

      service_class = stub_const('TestErrorService', Class.new(Servus::Base) do
        emits :critical_error, on: :error!

        def call
          error!('System failure')
        end
      end)

      expect { service_class.call }.to raise_error(Servus::Support::Errors::ServiceError)

      expect(handler_class.received_payload).to be_an_instance_of(Servus::Support::Errors::ServiceError)
      expect(handler_class.received_payload.message).to eq('System failure')
    end
  end
end
