# frozen_string_literal: true

require 'spec_helper'

module EventTestHelpers
  class NoopService < Servus::Base
    def call = success({})
  end
end

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

  describe 'event payload validation via emits DSL' do
    it 'validates payload against handler schema when emitting via emits DSL' do
      stub_const('ValidatedHandler', Class.new(Servus::Event) do
        event_name :validated_event

        schema payload: {
          type: 'object',
          required: ['user_id'],
          properties: {
            user_id: { type: 'integer' }
          }
        }

        invoke EventTestHelpers::NoopService do |_payload|
          {}
        end
      end)

      service_class = stub_const('ValidatedEmitService', Class.new(Servus::Base) do
        emits :validated_event, on: :success

        def call
          success({ user_id: 'not_an_integer' })
        end
      end)

      expect do
        service_class.call
      end.to raise_error(Servus::Support::Errors::ValidationError, /user_id/)
    end

    it 'does not raise when payload matches handler schema' do
      stub_const('ValidHandler', Class.new(Servus::Event) do
        event_name :valid_event

        schema payload: {
          type: 'object',
          required: ['user_id'],
          properties: {
            user_id: { type: 'integer' }
          }
        }

        invoke EventTestHelpers::NoopService do |_payload|
          {}
        end
      end)

      service_class = stub_const('ValidEmitService', Class.new(Servus::Base) do
        emits :valid_event, on: :success

        def call
          success({ user_id: 123 })
        end
      end)

      result = service_class.call
      expect(result).to be_success
    end

    it 'skips validation when handler has no payload schema' do
      stub_const('NoSchemaHandler', Class.new(Servus::Event) do
        event_name :unvalidated_event

        invoke EventTestHelpers::NoopService do |_payload|
          {}
        end
      end)

      service_class = stub_const('UnvalidatedEmitService', Class.new(Servus::Base) do
        emits :unvalidated_event, on: :success

        def call
          success({ anything: 'goes' })
        end
      end)

      result = service_class.call
      expect(result).to be_success
    end
  end

  describe 'event emission logging' do
    it 'logs when an event is emitted' do
      service_class = stub_const('LoggedEventService', Class.new(Servus::Base) do
        emits :user_created, on: :success

        def call
          success({ user_id: 123 })
        end
      end)

      allow(Servus::Support::Logger).to receive(:log_event)

      service_class.call

      expect(Servus::Support::Logger).to have_received(:log_event)
        .with(:user_created, hash_including(:user_id))
    end
  end

  describe 'automatic event emission' do
    it 'emits events on success' do
      service_class = stub_const('TestEventEmissionService', Class.new(Servus::Base) do
        emits :success_emission, on: :success

        def initialize(user_id:)
          @user_id = user_id
        end

        def call
          success({ user_id: @user_id, email: 'test@example.com' })
        end
      end)

      expect { service_class.call(user_id: 123) }
        .to emit_event(:success_emission)
        .with(hash_including(user_id: 123, email: 'test@example.com'))
    end

    it 'emits events on failure' do
      service_class = stub_const('TestFailureService', Class.new(Servus::Base) do
        emits :failure_emission, on: :failure

        def call
          failure('User not found')
        end
      end)

      expect { service_class.call }
        .to emit_event(:failure_emission)
    end

    it 'emits events with custom payload builder' do
      service_class = stub_const('TestCustomPayloadService', Class.new(Servus::Base) do
        emits :custom_payload_emission, on: :success, with: :custom_payload

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

      expect { service_class.call(user_id: 456) }
        .to emit_event(:custom_payload_emission)
        .with(hash_including(id: 456))
    end

    it 'emits multiple events for the same trigger' do
      service_class = stub_const('TestMultipleEventsService', Class.new(Servus::Base) do
        emits :multi_event_one, on: :success
        emits :multi_event_two, on: :success

        def call
          success({ data: 'test' })
        end
      end)

      emitted = []
      subscription = Servus::Events::Bus.subscribe_all do |event_name, _payload, **|
        emitted << event_name
      end

      service_class.call

      ActiveSupport::Notifications.unsubscribe(subscription)

      expect(emitted).to include(:multi_event_one, :multi_event_two)
    end

    it 'emits events on explicit error!' do
      service_class = stub_const('TestErrorService', Class.new(Servus::Base) do
        emits :critical_error_emission, on: :error!

        def call
          error!('System failure')
        end
      end)

      emitted = []
      subscription = Servus::Events::Bus.subscribe_all do |event_name, _payload, **|
        emitted << event_name
      end

      service_class.call rescue nil

      ActiveSupport::Notifications.unsubscribe(subscription)

      expect(emitted).to include(:critical_error_emission)
    end
  end
end
