# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Servus::Events::Invocation do
  let(:service_class) do
    Class.new(Servus::Base) do
      def self.call(**args)
        @called_with = args
        Servus::Support::Response.new(true, args, nil)
      end

      def self.call_async(**args)
        @async_called_with = args
      end

      class << self
        attr_reader :called_with, :async_called_with
      end
    end
  end

  describe '#execute' do
    it 'calls the service synchronously when async is not set' do
      invocation = described_class.new(
        service: service_class,
        params: { user_id: 123 },
        options: {}
      )

      invocation.execute

      expect(service_class.called_with).to eq({ user_id: 123 })
    end

    it 'calls the service asynchronously when async is true' do
      invocation = described_class.new(
        service: service_class,
        params: { user_id: 456 },
        options: { async: true }
      )

      invocation.execute

      expect(service_class.async_called_with).to eq({ user_id: 456 })
    end

    it 'passes queue option to call_async' do
      invocation = described_class.new(
        service: service_class,
        params: { user_id: 789 },
        options: { async: true, queue: :mailers }
      )

      invocation.execute

      expect(service_class.async_called_with).to eq({ user_id: 789, queue: :mailers })
    end

    it 'passes wait option to call_async' do
      invocation = described_class.new(
        service: service_class,
        params: { user_id: 1 },
        options: { async: true, wait: 300 }
      )

      invocation.execute

      expect(service_class.async_called_with).to eq({ user_id: 1, wait: 300 })
    end

    it 'passes priority option to call_async' do
      invocation = described_class.new(
        service: service_class,
        params: { user_id: 1 },
        options: { async: true, priority: 10 }
      )

      invocation.execute

      expect(service_class.async_called_with).to eq({ user_id: 1, priority: 10 })
    end

    it 'passes multiple scheduling options to call_async' do
      invocation = described_class.new(
        service: service_class,
        params: { user_id: 1 },
        options: { async: true, queue: :critical, wait: 600, priority: 5 }
      )

      invocation.execute

      expect(service_class.async_called_with).to eq({
                                                      user_id: 1,
                                                      queue: :critical,
                                                      wait: 600,
                                                      priority: 5
                                                    })
    end
  end

  describe '#key' do
    it 'is the same for identical service and params' do
      a = described_class.new(service: service_class, params: { user_id: 1 }, options: {})
      b = described_class.new(service: service_class, params: { user_id: 1 }, options: {})

      expect(a.key).to eq(b.key)
    end

    it 'differs when params differ' do
      a = described_class.new(service: service_class, params: { user_id: 1 }, options: {})
      b = described_class.new(service: service_class, params: { user_id: 2 }, options: {})

      expect(a.key).not_to eq(b.key)
    end

    it 'excludes options from the key' do
      a = described_class.new(service: service_class, params: { user_id: 1 }, options: {})
      b = described_class.new(service: service_class, params: { user_id: 1 }, options: { async: true, queue: :low })

      expect(a.key).to eq(b.key)
    end
  end
end
