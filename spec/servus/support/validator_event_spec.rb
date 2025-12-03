# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Servus::Support::Validator, 'event payload validation' do
  describe '.validate_event_payload!' do
    it 'returns true when payload is valid' do
      handler_class = Class.new(Servus::EventHandler) do
        handles :test_event

        schema payload: {
          type: 'object',
          required: ['user_id'],
          properties: {
            user_id: { type: 'integer' }
          }
        }
      end

      expect(described_class.validate_event_payload!(handler_class, { user_id: 123 })).to be true
    end

    it 'raises ValidationError when payload is invalid' do
      handler_class = Class.new(Servus::EventHandler) do
        handles :test_event

        schema payload: {
          type: 'object',
          required: ['user_id'],
          properties: {
            user_id: { type: 'integer' }
          }
        }
      end

      expect { described_class.validate_event_payload!(handler_class, { user_id: 'invalid' }) }
        .to raise_error(Servus::Support::Errors::ValidationError, /user_id/)
    end

    it 'returns true when no schema is defined' do
      handler_class = Class.new(Servus::EventHandler) do
        handles :test_event
      end

      expect(described_class.validate_event_payload!(handler_class, { any: 'data' })).to be true
    end
  end
end
