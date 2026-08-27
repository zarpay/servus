# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Servus::Events::ClassRouter do
  after { Servus::Events::Bus.clear }

  let(:router) { described_class.new }

  let(:service_a) do
    Class.new(Servus::Base) do
      def self.call(**args)
        Servus::Support::Response.new(true, args, nil)
      end
    end
  end

  let(:service_b) do
    Class.new(Servus::Base) do
      def self.call(**args)
        Servus::Support::Response.new(true, args, nil)
      end
    end
  end

  describe '#resolve' do
    it 'returns invocations from registered event classes' do
      svc = service_a
      Class.new(Servus::Event) do
        event_name :order_placed

        enqueue svc do |payload|
          { user_id: payload[:user_id] }
        end
      end

      invocations = router.resolve(:order_placed, { user_id: 42 })

      expect(invocations.length).to eq(1)
      expect(invocations.first).to be_a(Servus::Events::Invocation)
      expect(invocations.first.params).to eq({ user_id: 42 })
    end

    it 'returns multiple invocations from one event class' do
      svc_a = service_a
      svc_b = service_b
      Class.new(Servus::Event) do
        event_name :order_placed

        enqueue svc_a do |payload|
          { user_id: payload[:user_id] }
        end

        enqueue svc_b do |payload|
          { order_id: payload[:order_id] }
        end
      end

      invocations = router.resolve(:order_placed, { user_id: 1, order_id: 99 })

      expect(invocations.length).to eq(2)
    end

    it 'filters out invocations that fail the if condition' do
      svc = service_a
      Class.new(Servus::Event) do
        event_name :order_placed

        enqueue svc, if: ->(p) { p[:premium] } do |payload|
          { user_id: payload[:user_id] }
        end
      end

      invocations = router.resolve(:order_placed, { user_id: 1, premium: false })

      expect(invocations).to be_empty
    end

    it 'includes invocations that pass the if condition' do
      svc = service_a
      Class.new(Servus::Event) do
        event_name :order_placed

        enqueue svc, if: ->(p) { p[:premium] } do |payload|
          { user_id: payload[:user_id] }
        end
      end

      invocations = router.resolve(:order_placed, { user_id: 1, premium: true })

      expect(invocations.length).to eq(1)
    end

    it 'returns empty array when no events registered for the name' do
      invocations = router.resolve(:nonexistent_event, { user_id: 1 })

      expect(invocations).to eq([])
    end
  end
end
