# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Servus::Events::Bus do
  after do
    described_class.clear
    Servus.config.routers = nil
    ServiceA.reset!
    ServiceB.reset!
  end

  describe '.register_event' do
    it 'registers an event class for an event name' do
      event_class = Class.new(Servus::Event) do
        event_name :test_event
      end

      expect(described_class.event_for(:test_event)).to eq(event_class)
    end

    it 'raises if a second class registers for the same event name' do
      Class.new(Servus::Event) do
        event_name :duplicate_event
      end

      expect do
        Class.new(Servus::Event) do
          event_name :duplicate_event
        end
      end.to raise_error(RuntimeError, /already registered/)
    end
  end

  describe '.emit' do
    it 'delegates to configured routers and executes invocations' do
      Class.new(Servus::Event) do
        event_name :test_event

        invoke ServiceA do |payload|
          { user_id: payload[:user_id] }
        end
      end

      described_class.emit(:test_event, { user_id: 42 })

      expect(ServiceA.calls).to eq([{ user_id: 42 }])
    end

    it 'deduplicates invocations by key — first wins' do
      invocation = Servus::Events::Invocation.new(
        service: ServiceA,
        params: { user_id: 1 },
        options: {}
      )

      router_a = Class.new(Servus::Events::Router) do
        define_method(:resolve) { |_name, _payload| [invocation] }
      end

      router_b = Class.new(Servus::Events::Router) do
        define_method(:resolve) { |_name, _payload| [invocation] }
      end

      Servus.config.routers = [router_a.new, router_b.new]

      described_class.emit(:test_event, { user_id: 1 })

      expect(ServiceA.calls.length).to eq(1)
    end

    it 'processes routers in config array order' do
      inv_a = Servus::Events::Invocation.new(service: ServiceA, params: { id: 1 }, options: {})
      inv_b = Servus::Events::Invocation.new(service: ServiceB, params: { id: 2 }, options: {})

      router_a = Class.new(Servus::Events::Router) do
        define_method(:resolve) { |_name, _payload| [inv_a] }
      end

      router_b = Class.new(Servus::Events::Router) do
        define_method(:resolve) { |_name, _payload| [inv_b] }
      end

      Servus.config.routers = [router_a.new, router_b.new]

      described_class.emit(:test_event, {})

      expect(ServiceA.calls).to eq([{ id: 1 }])
      expect(ServiceB.calls).to eq([{ id: 2 }])
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
