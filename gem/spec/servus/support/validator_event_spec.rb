# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Servus::Support::Validator, 'event payload validation' do
  after { Servus::Events::Bus.clear }

  describe '.validate_event_payload!' do
    it 'returns true when payload is valid' do
      event_class = Class.new(Servus::Event) do
        event_name :validator_valid_payload

        schema payload: {
          type: 'object',
          required: ['user_id'],
          properties: {
            user_id: { type: 'integer' }
          }
        }
      end

      expect(described_class.validate_event_payload!(event_class, { user_id: 123 })).to be true
    end

    it 'raises ValidationError when payload is invalid' do
      event_class = Class.new(Servus::Event) do
        event_name :validator_invalid_payload

        schema payload: {
          type: 'object',
          required: ['user_id'],
          properties: {
            user_id: { type: 'integer' }
          }
        }
      end

      expect { described_class.validate_event_payload!(event_class, { user_id: 'invalid' }) }
        .to raise_error(Servus::Support::Errors::ValidationError, /user_id/)
    end

    it 'returns true when no schema is defined' do
      event_class = Class.new(Servus::Event) do
        event_name :validator_no_schema
      end

      expect(described_class.validate_event_payload!(event_class, { any: 'data' })).to be true
    end

    context 'with require_event_payload_schema enabled' do
      after { Servus.config.require_event_payload_schema = false }

      it 'raises SchemaRequiredError when no payload schema is defined' do
        Servus.config.require_event_payload_schema = true

        event_class = Class.new(Servus::Event) do
          event_name :validator_schema_required
        end

        expect do
          described_class.validate_event_payload!(event_class, { any: 'data' })
        end.to raise_error(Servus::Support::Errors::SchemaRequiredError, /require_event_payload_schema/)
      end

      it 'does not raise when payload schema is defined' do
        Servus.config.require_event_payload_schema = true

        event_class = Class.new(Servus::Event) do
          event_name :validator_schema_present

          schema payload: {
            type: 'object',
            properties: { any: { type: 'string' } }
          }
        end

        expect(described_class.validate_event_payload!(event_class, { any: 'data' })).to be true
      end
    end
  end
end
