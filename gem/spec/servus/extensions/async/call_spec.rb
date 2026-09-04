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

  # With the :inline and :test adapters, perform_later runs the service — so a
  # service's own failure surfaces here. Wrapping it as an enqueue failure would
  # blame the wrong layer and hide the real cause.
  it 'lets a service error through rather than reporting an enqueue failure' do
    allow(job_class).to receive(:perform_later)
      .and_raise(Servus::Support::Errors::ValidationError, 'Invalid arguments')

    expect do
      AsyncEmailService.call_async(test: 'data')
    end.to raise_error(Servus::Support::Errors::ValidationError, /Invalid arguments/)
  end

  it 'lets an event error through as well' do
    allow(job_class).to receive(:perform_later)
      .and_raise(Servus::Events::Errors::AnonymousServiceError, 'anonymous')

    expect do
      AsyncEmailService.call_async(test: 'data')
    end.to raise_error(Servus::Events::Errors::AnonymousServiceError)
  end

  describe 'a job constant the application already owns' do
    # Foo alongside a hand-written FooJob is ordinary Rails. Overwriting it left the
    # app's job reachable by name but stripped of its own constants and methods, and
    # said nothing.
    it 'leaves the application class in place and warns' do
      stub_const('OwnedJobNamespace', Module.new)
      app_job = Class.new(ActiveJob::Base)
      OwnedJobNamespace.const_set(:ServiceJob, app_job)

      allow(Servus::Support::Logger).to receive(:log_job_class_conflict)

      OwnedJobNamespace.module_eval('class Service < AsyncFixtureService; end', __FILE__, __LINE__)

      expect(OwnedJobNamespace::ServiceJob).to equal(app_job)
      expect(Servus::Support::Logger)
        .to have_received(:log_job_class_conflict)
        .with(OwnedJobNamespace::Service, 'OwnedJobNamespace::ServiceJob')
    end

    it 'still builds a job class so the service keeps working' do
      stub_const('OwnedJobNamespace2', Module.new)
      OwnedJobNamespace2.const_set(:ServiceJob, Class.new(ActiveJob::Base))

      allow(Servus::Support::Logger).to receive(:log_job_class_conflict)

      OwnedJobNamespace2.module_eval('class Service < AsyncFixtureService; end', __FILE__, __LINE__)

      job = OwnedJobNamespace2::Service.servus_job_class

      expect(job.servus_service).to eq(OwnedJobNamespace2::Service)
      expect(job.name).to be_nil
    end

    # A pending Zeitwerk autoload is the app's constant. Resolving it to find out
    # would run app code in the middle of defining a service.
    it 'does not resolve a pending autoload to decide' do
      stub_const('AutoloadNamespace', Module.new)
      AutoloadNamespace.autoload(:ServiceJob, '/nonexistent/service_job.rb')

      allow(Servus::Support::Logger).to receive(:log_job_class_conflict)

      expect do
        AutoloadNamespace.module_eval('class Service < AsyncFixtureService; end', __FILE__, __LINE__)
      end.not_to raise_error

      expect(AutoloadNamespace.autoload?(:ServiceJob)).to eq('/nonexistent/service_job.rb')
    end

    # A generated job left on an unmanaged namespace survives a development reload,
    # so the redefined service has to be able to reclaim its own constant.
    it 'reclaims a constant holding a previously generated job' do
      stub_const('ReloadNamespace', Module.new)
      ReloadNamespace.module_eval('class Service < AsyncFixtureService; end', __FILE__, __LINE__)
      first = ReloadNamespace::ServiceJob

      # A reload replaces the service class; the generated job constant is not
      # Zeitwerk-managed and is still sitting there when the new one is defined.
      ReloadNamespace.send(:remove_const, :Service)
      ReloadNamespace.module_eval('class Service < AsyncFixtureService; end', __FILE__, __LINE__)

      expect(ReloadNamespace::ServiceJob).not_to equal(first)
      expect(ReloadNamespace::ServiceJob.servus_service).to eq(ReloadNamespace::Service)
    end
  end

  describe '.install!' do
    # Servus's railtie force-loads app/events/*_event.rb, and every service named by
    # an `enqueue` there loads with it — before anything touches ActiveJob::Base and
    # therefore before `inherited` exists to publish job constants. A worker resolves
    # jobs by name and never calls call_async, so it failed deserialization.
    it 'backfills job classes for services defined before the extension installed' do
      stub_const('PreloadNamespace', Module.new)
      PreloadNamespace.module_eval('class Service < Servus::Base; end', __FILE__, __LINE__)

      # The state a service reaches when it loads before ActiveJob: the class exists,
      # `inherited` never published its job, and nothing has asked for one since.
      PreloadNamespace.send(:remove_const, :ServiceJob)
      PreloadNamespace::Service.remove_instance_variable(:@servus_job_class)

      expect { 'PreloadNamespace::ServiceJob'.constantize }.to raise_error(NameError)

      Servus::Extensions::Async.install!

      expect(PreloadNamespace.const_defined?(:ServiceJob, false)).to be(true)
      expect(PreloadNamespace::ServiceJob.servus_service).to eq(PreloadNamespace::Service)
    end

    it 'skips services with no constant to publish under' do
      anonymous = Class.new(Servus::Base)

      # A service whose namespace has gone — the state a stubbed or reloaded
      # constant leaves behind. Resolving its parent would raise.
      # Set and removed directly rather than with stub_const, whose teardown would
      # trip over the constant already being gone.
      Object.const_set(:DepartedNamespace, Module.new)
      DepartedNamespace.module_eval('class Service < Servus::Base; end', __FILE__, __LINE__)
      departed = DepartedNamespace::Service
      Object.send(:remove_const, :DepartedNamespace)

      expect { Servus::Extensions::Async.install! }.not_to raise_error
      expect(anonymous.instance_variable_get(:@servus_job_class)).to be_nil
      expect(departed.name).to eq('DepartedNamespace::Service')
    end
  end

  describe 'anonymous services' do
    # ActiveJob resolves a job on the worker by its serialized class name, so
    # there is nothing to serialize for a class with no name.
    it 'raises a named error rather than NoMethodError on nil' do
      expect { Class.new(Servus::Base).call_async(test: 'data') }
        .to raise_error(Servus::Events::Errors::AnonymousServiceError, /anonymous/)
    end
  end
end
