# frozen_string_literal: true

require 'spec_helper'

require 'servus/extensions/async/ext'

RSpec.describe '.call_async extension', type: :job do
  let(:job_class) { Servus::Extensions::Async::Job }

  # Define a dummy service class for testing
  before do
    # Make sure the extension is loaded and applied
    Servus::Base.extend(Servus::Extensions::Async::Call)

    stub_const('DummyService', Class.new(Servus::Base) do
      def initialize(arg1:, arg2:)
        super()
        @arg1 = arg1
        @arg2 = arg2
      end

      def call
        success("Called with #{@arg1} and #{@arg2}")
      end
    end)
  end

  it 'responds to .call_async' do
    expect(DummyService).to respond_to(:call_async)
  end

  it 'enqueues Servus::Extensions::Async::Job with name and args' do
    allow(job_class).to receive(:perform_later).and_call_original

    DummyService.call_async(foo: 'bar', baz: 123)

    expect(job_class)
      .to have_received(:perform_later)
      .with(
        name: 'DummyService',
        args: { foo: 'bar', baz: 123 }
      )
  end

  it 'respects ActiveJob options like queue and priority' do
    allow(job_class).to receive(:set).and_call_original

    DummyService.call_async(
      foo: 'a',
      bar: 'b',
      queue: :low_priority,
      priority: 10,
      job_options: { some_meta: 'test' }
    )

    expect(job_class)
      .to have_received(:set)
      .with(
        priority: 10,
        some_meta: 'test',
        queue: :low_priority
      )
  end

  it 'filters out ActiveJob-specific keys from service args' do
    allow(job_class).to receive(:set).and_return(job_class)
    allow(job_class).to receive(:perform_later).and_call_original

    DummyService.call_async(
      foo: 'X',
      bar: 'Y',
      wait: 5.minutes,
      job_options: { debug: true }
    )

    expect(job_class)
      .to have_received(:perform_later)
      .with(name: 'DummyService', args: { foo: 'X', bar: 'Y' })
      .once
  end

  it 'raises JobEnqueueError if job enqueueing fails' do
    allow(job_class).to receive(:perform_later).and_raise(StandardError, 'Simulated failure')

    expect do
      DummyService.call_async(test: 'data')
    end.to raise_error(Servus::Extensions::Async::Errors::JobEnqueueError, /Failed to enqueue async job/)
  end
end
