# frozen_string_literal: true

require 'spec_helper'

require 'servus/extensions/async/ext'

RSpec.describe '.call_async extension', type: :job do
  # Make sure the extension is loaded and applied.
  before { Servus::Base.extend(Servus::Extensions::Async::Call) }

  let(:job_class) { AsyncEmailService.servus_job_class }

  it 'responds to .call_async' do
    expect(AsyncEmailService).to respond_to(:call_async)
  end

  it 'generates a named sibling job class bound to the service' do
    expect(AsyncEmailService.servus_job_class).to eq(AsyncEmailServiceJob)
    expect(AsyncEmailServiceJob.servus_service).to eq(AsyncEmailService)
    expect(AsyncEmailServiceJob.ancestors).to include(Servus::Extensions::Async::Job)
  end

  it 'names the job so a worker can resolve it from the serialized string' do
    job = AsyncNamespace::DeliverService.servus_job_class

    expect('AsyncNamespace::DeliverServiceJob'.constantize).to eq(job)
  end

  it 'eagerly generates the job when a named service class is defined' do
    stub_const('EagerlyDefined', Module.new)
    # String eval so the `class` keyword nests under EagerlyDefined and the
    # subclass has its name at `inherited` time (the production eager-load path).
    EagerlyDefined.module_eval('class Service < AsyncFixtureService; end', __FILE__, __LINE__)

    expect(EagerlyDefined.const_defined?(:ServiceJob, false)).to be(true)
    expect(EagerlyDefined::ServiceJob.servus_service).to eq(EagerlyDefined::Service)
  end

  it 'enqueues the service’s named job with the service arguments' do
    allow(job_class).to receive(:perform_later).and_call_original

    AsyncEmailService.call_async(
      foo: 'bar',
      baz: 123
    )

    expect(job_class).to have_received(:perform_later).with(
      foo: 'bar',
      baz: 123
    )
  end

  it 'respects ActiveJob options like queue and priority' do
    allow(job_class).to receive(:set).and_call_original

    AsyncEmailService.call_async(
      foo: 'a',
      bar: 'b',
      queue: :low_priority,
      priority: 10,
      job_options: { some_meta: 'test' }
    )

    expect(job_class).to have_received(:set).with(
      priority: 10,
      some_meta: 'test',
      queue: :low_priority
    )
  end

  it 'filters out ActiveJob-specific keys from service args' do
    allow(job_class).to receive(:set).and_return(job_class)
    allow(job_class).to receive(:perform_later).and_call_original

    AsyncEmailService.call_async(
      foo: 'X',
      bar: 'Y',
      wait: 5.minutes,
      job_options: { debug: true }
    )

    expect(job_class).to have_received(:perform_later).with(
      foo: 'X',
      bar: 'Y'
    ).once
  end

  it 'raises JobEnqueueError if job enqueueing fails' do
    allow(job_class).to receive(:perform_later).and_raise(StandardError, 'Simulated failure')

    expect do
      AsyncEmailService.call_async(test: 'data')
    end.to raise_error(Servus::Extensions::Async::Errors::JobEnqueueError, /Failed to enqueue async job/)
  end
end
