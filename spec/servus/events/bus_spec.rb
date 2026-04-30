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

  describe '.subscribe_all' do
    it 'yields event_name and payload as positional args' do
      received = []

      described_class.subscribe_all do |event_name, payload, **|
        received << { event_name: event_name, payload: payload }
      end

      described_class.emit(:gold_transferred, { amount: 50 })
      described_class.emit(:user_created, { user_id: 1 })

      expect(received.length).to eq(2)
      expect(received[0]).to eq(event_name: :gold_transferred, payload: { amount: 50 })
      expect(received[1]).to eq(event_name: :user_created, payload: { user_id: 1 })
    end

    it 'yields started_at, finished_at, and id as keyword args' do
      received = nil

      described_class.subscribe_all do |_event_name, _payload, started_at:, finished_at:, id:|
        received = { started_at: started_at, finished_at: finished_at, id: id }
      end

      described_class.emit(:test_event, { foo: 'bar' })

      expect(received[:started_at]).to be_a(Time)
      expect(received[:finished_at]).to be_a(Time)
      expect(received[:id]).to be_a(String)
    end

    it 'returns the subscription for manual unsubscribe' do
      received = false
      subscription = described_class.subscribe_all { |_event_name, _payload, **| received = true }

      described_class.emit(:test_event, {})
      expect(received).to be true

      ActiveSupport::Notifications.unsubscribe(subscription)
    end
  end
end
