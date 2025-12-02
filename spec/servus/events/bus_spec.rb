# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Servus::Events::Bus do
  # Clear handlers between tests to avoid state leakage
  after do
    described_class.clear
  end

  describe '.register_handler' do
    it 'registers a handler for an event' do
      handler_class = Class.new

      described_class.register_handler(:test_event, handler_class)

      handlers = described_class.handlers_for(:test_event)
      expect(handlers).to include(handler_class)
    end
  end

  describe '.emit' do
    it 'dispatches the event to all registered handlers' do
      handler_class = Class.new do
        def self.handle(payload)
          @handled_payload = payload
        end

        class << self
          attr_reader :handled_payload
        end
      end

      described_class.register_handler(:test_event, handler_class)

      payload = { user_id: 123 }
      described_class.emit(:test_event, payload)

      expect(handler_class.handled_payload).to eq(payload)
    end
  end
end
