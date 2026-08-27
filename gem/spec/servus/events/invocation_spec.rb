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

  def invocation(params: { user_id: 123 }, options: {})
    described_class.new(service: service_class, params: params, options: options)
  end

  describe '#enqueue' do
    it 'enqueues the service' do
      invocation.enqueue

      expect(service_class.async_called_with).to eq({ user_id: 123 })
    end

    # Sync invocation is gone entirely — there is no option that brings it back.
    it 'never calls the service inline' do
      invocation.enqueue

      expect(service_class.called_with).to be_nil
    end

    it 'passes the queue option through' do
      invocation(options: { queue: :mailers }).enqueue

      expect(service_class.async_called_with).to eq({ user_id: 123, queue: :mailers })
    end

    it 'passes the wait option through' do
      invocation(options: { wait: 300 }).enqueue

      expect(service_class.async_called_with).to eq({ user_id: 123, wait: 300 })
    end

    it 'passes the priority option through' do
      invocation(options: { priority: 10 }).enqueue

      expect(service_class.async_called_with).to eq({ user_id: 123, priority: 10 })
    end

    it 'passes multiple scheduling options through' do
      invocation(options: { queue: :critical, wait: 600, priority: 5 }).enqueue

      expect(service_class.async_called_with).to eq({
                                                      user_id: 123,
                                                      queue: :critical,
                                                      wait: 600,
                                                      priority: 5
                                                    })
    end

    it 'drops options that are not scheduling options' do
      invocation(options: { nonsense: true }).enqueue

      expect(service_class.async_called_with).to eq({ user_id: 123 })
    end

    context 'when the service cannot be enqueued' do
      let(:service_class) { Class.new(Servus::Base) }

      before { allow(service_class).to receive(:respond_to?).with(:call_async).and_return(false) }

      # Without ActiveJob this used to be a bare NoMethodError raised from inside
      # the emitting service's after_call.
      it 'raises naming the service and what to do' do
        expect { invocation.enqueue }
          .to raise_error(Servus::Events::Errors::AsyncBackendMissingError) { |error|
            expect(error.message).to include('ActiveJob is not loaded')
            expect(error.message).to include('Require active_job')
          }
      end
    end
  end

  describe '#key' do
    it 'is the same for identical service and params' do
      expect(invocation(params: { user_id: 1 }).key).to eq(invocation(params: { user_id: 1 }).key)
    end

    it 'differs when params differ' do
      expect(invocation(params: { user_id: 1 }).key).not_to eq(invocation(params: { user_id: 2 }).key)
    end

    it 'excludes options from the key' do
      a = invocation(params: { user_id: 1 }, options: {})
      b = invocation(params: { user_id: 1 }, options: { queue: :low, priority: 5 })

      expect(a.key).to eq(b.key)
    end
  end
end
