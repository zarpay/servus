# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Servus::Events::Emitter do
  after { Servus::Events::Bus.clear }

  describe 'EMISSION_TRIGGERS' do
    it 'lists the supported triggers' do
      expect(described_class::EMISSION_TRIGGERS).to eq(%i[success failure error!])
    end

    it 'is frozen' do
      expect(described_class::EMISSION_TRIGGERS).to be_frozen
    end
  end

  describe '.emits' do
    let(:service_class) { Class.new(Servus::Base) }

    it 'accepts every supported trigger' do
      described_class::EMISSION_TRIGGERS.each do |trigger|
        expect { service_class.emits(:something_happened, on: trigger) }.not_to raise_error
      end
    end

    it 'rejects an unsupported trigger' do
      expect { service_class.emits(:something_happened, on: :whenever) }
        .to raise_error(ArgumentError, /Invalid trigger: whenever/)
    end

    # The bang is easy to drop, and the resulting event would simply never fire.
    it 'names error! with its bang when rejecting the unbanged spelling' do
      expect { service_class.emits(:something_happened, on: :error) }
        .to raise_error(ArgumentError, /error!/)
    end
  end

  describe 'payload schema enforcement' do
    subject(:call_service) { service_class.call }

    let(:service_class) do
      stub_const('UnregisteredEmitService', Class.new(Servus::Base) do
        emits :nothing_listens_to_this, on: :success

        def call = success({ any: 'data' })
      end)
    end

    after { Servus.config.require_event_payload_schema = false }

    context 'when no Event class is registered for the emitted name' do
      it 'emits without validating while enforcement is off' do
        expect { call_service }.not_to raise_error
      end

      # Without this the one flag whose job is to make a missing payload schema
      # loud was silently bypassed on the events that had no schema at all.
      it 'raises once enforcement is on' do
        Servus.config.require_event_payload_schema = true

        expect { call_service }
          .to raise_error(Servus::Support::Errors::SchemaRequiredError, /require_event_payload_schema/)
      end

      it 'names the service and the event it could not validate' do
        Servus.config.require_event_payload_schema = true

        expect { call_service }.to raise_error(Servus::Support::Errors::SchemaRequiredError) { |error|
          expect(error.message).to include('UnregisteredEmitService')
          expect(error.message).to include('nothing_listens_to_this')
        }
      end
    end

    context 'when an Event class is registered' do
      let(:service_class) do
        stub_const('RegisteredEmitService', Class.new(Servus::Base) do
          emits :registered_emission, on: :success

          def call = success({ user_id: 7 })
        end)
      end

      before do
        stub_const('RegisteredEmission', Class.new(Servus::Event) do
          event_name :registered_emission

          schema payload: {
            type: 'object',
            required: ['user_id'],
            properties: { user_id: { type: 'integer' } }
          }
        end)
      end

      it 'validates against its schema rather than raising' do
        Servus.config.require_event_payload_schema = true

        expect { call_service }.not_to raise_error
      end

      it 'still reports a payload that does not match' do
        service_class.define_method(:call) { success({ user_id: 'seven' }) }

        expect { call_service }
          .to raise_error(Servus::Support::Errors::ValidationError, /user_id/)
      end
    end
  end
end
