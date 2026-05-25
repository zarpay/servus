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
    before { Servus::Events::Bus.enable_logging! }

    it 'logs when an event is emitted with event_id and duration' do
      service_class = stub_const('LoggedEventService', Class.new(Servus::Base) do
        emits :logged_event, on: :success

        def call
          success({ user_id: 123 })
        end
      end)

      allow(Servus::Support::Logger).to receive(:log_event)

      service_class.call

      expect(Servus::Support::Logger).to have_received(:log_event)
        .with(:logged_event, hash_including(:user_id), event_id: a_kind_of(String), duration_ms: a_kind_of(Float))
    end
  end

  describe 'conditional event emission' do
    describe 'if: condition' do
      it 'emits when the lambda returns truthy' do
        service_class = stub_const('IfLambdaTruthyService', Class.new(Servus::Base) do
          emits :conditional_event, on: :success, if: ->(result) { result.data[:amount] > 100 }

          def call
            success({ amount: 150 })
          end
        end)

        expect { service_class.call }.to emit_event(:conditional_event)
      end

      it 'does not emit when the lambda returns falsy' do
        service_class = stub_const('IfLambdaFalsyService', Class.new(Servus::Base) do
          emits :conditional_event, on: :success, if: ->(result) { result.data[:amount] > 100 }

          def call
            success({ amount: 50 })
          end
        end)

        expect { service_class.call }.not_to emit_event(:conditional_event)
      end

      it 'emits when the method reference returns truthy' do
        service_class = stub_const('IfMethodTruthyService', Class.new(Servus::Base) do
          emits :conditional_event, on: :success, if: :large_amount?

          def call
            success({ amount: 150 })
          end

          private

          def large_amount?(result)
            result.data[:amount] > 100
          end
        end)

        expect { service_class.call }.to emit_event(:conditional_event)
      end

      it 'does not emit when the method reference returns falsy' do
        service_class = stub_const('IfMethodFalsyService', Class.new(Servus::Base) do
          emits :conditional_event, on: :success, if: :large_amount?

          def call
            success({ amount: 50 })
          end

          private

          def large_amount?(result)
            result.data[:amount] > 100
          end
        end)

        expect { service_class.call }.not_to emit_event(:conditional_event)
      end
    end

    describe 'unless: condition' do
      it 'does not emit when the lambda returns truthy' do
        service_class = stub_const('UnlessLambdaTruthyService', Class.new(Servus::Base) do
          emits :conditional_event, on: :success, unless: ->(result) { result.data[:internal] }

          def call
            success({ internal: true })
          end
        end)

        expect { service_class.call }.not_to emit_event(:conditional_event)
      end

      it 'emits when the lambda returns falsy' do
        service_class = stub_const('UnlessLambdaFalsyService', Class.new(Servus::Base) do
          emits :conditional_event, on: :success, unless: ->(result) { result.data[:internal] }

          def call
            success({ internal: false })
          end
        end)

        expect { service_class.call }.to emit_event(:conditional_event)
      end

      it 'does not emit when the method reference returns truthy' do
        service_class = stub_const('UnlessMethodTruthyService', Class.new(Servus::Base) do
          emits :conditional_event, on: :success, unless: :internal_transfer?

          def call
            success({ internal: true })
          end

          private

          def internal_transfer?(result)
            result.data[:internal]
          end
        end)

        expect { service_class.call }.not_to emit_event(:conditional_event)
      end

      it 'emits when the method reference returns falsy' do
        service_class = stub_const('UnlessMethodFalsyService', Class.new(Servus::Base) do
          emits :conditional_event, on: :success, unless: :internal_transfer?

          def call
            success({ internal: false })
          end

          private

          def internal_transfer?(result)
            result.data[:internal]
          end
        end)

        expect { service_class.call }.to emit_event(:conditional_event)
      end
    end

    describe 'combining if: and unless:' do
      it 'emits when both conditions pass' do
        service_class = stub_const('BothConditionsPassService', Class.new(Servus::Base) do
          emits :conditional_event, on: :success,
                                    if: ->(result) { result.data[:amount] > 50 },
                                    unless: ->(result) { result.data[:internal] }

          def call
            success({ amount: 150, internal: false })
          end
        end)

        expect { service_class.call }.to emit_event(:conditional_event)
      end

      it 'does not emit when if: passes but unless: blocks' do
        service_class = stub_const('UnlessBlocksService', Class.new(Servus::Base) do
          emits :conditional_event, on: :success,
                                    if: ->(result) { result.data[:amount] > 50 },
                                    unless: ->(result) { result.data[:internal] }

          def call
            success({ amount: 150, internal: true })
          end
        end)

        expect { service_class.call }.not_to emit_event(:conditional_event)
      end

      it 'does not emit when unless: passes but if: blocks' do
        service_class = stub_const('IfBlocksService', Class.new(Servus::Base) do
          emits :conditional_event, on: :success,
                                    if: ->(result) { result.data[:amount] > 50 },
                                    unless: ->(result) { result.data[:internal] }

          def call
            success({ amount: 10, internal: false })
          end
        end)

        expect { service_class.call }.not_to emit_event(:conditional_event)
      end
    end

    it 'backwards compatible: always emits when no condition is given' do
      service_class = stub_const('UnconditionalEmitService', Class.new(Servus::Base) do
        emits :unconditional_event, on: :success

        def call
          success({ data: 'anything' })
        end
      end)

      expect { service_class.call }.to emit_event(:unconditional_event)
    end

    it 'still builds payload correctly when condition passes' do
      service_class = stub_const('ConditionalPayloadService', Class.new(Servus::Base) do
        emits :conditional_event, on: :success,
                                  if: ->(result) { result.data[:amount] > 100 }

        def call
          success({ amount: 150, label: 'large' })
        end
      end)

      expect { service_class.call }
        .to emit_event(:conditional_event)
        .with(hash_including(amount: 150, label: 'large'))
    end

    context 'instance variable access in procs (regression: instance_exec binding)' do
      it 'condition proc can read an instance variable set in initialize' do
        service_class = stub_const('IvarConditionService', Class.new(Servus::Base) do
          emits :ivar_event, on: :success, unless: ->(_result) { @suppress }

          def initialize(suppress: false)
            @suppress = suppress
          end

          def call
            success({})
          end
        end)

        expect { service_class.call(suppress: false) }.to emit_event(:ivar_event)
        expect { service_class.call(suppress: true) }.not_to emit_event(:ivar_event)
      end

      it 'payload builder block can read an instance variable set in initialize' do
        service_class = stub_const('IvarPayloadService', Class.new(Servus::Base) do
          emits :ivar_payload_event, on: :success do |_result|
            { label: @label }
          end

          def initialize(label:)
            @label = label
          end

          def call
            success({})
          end
        end)

        expect { service_class.call(label: 'vip') }
          .to emit_event(:ivar_payload_event)
          .with(hash_including(label: 'vip'))
      end
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

      begin
        service_class.call
      rescue StandardError
        nil
      end

      ActiveSupport::Notifications.unsubscribe(subscription)

      expect(emitted).to include(:critical_error_emission)
    end
  end
end
