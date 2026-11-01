# frozen_string_literal: true

require 'spec_helper'

require 'servus/extensions/async/ext'

RSpec.describe '.async DSL', type: :job do
  before { Servus::Base.extend(Servus::Extensions::Async::Call) }

  it 'routes the job to the given queue' do
    AsyncQueueService.async(queue: :critical)

    expect(AsyncQueueService.servus_job_class.new.queue_name).to eq('critical')
  end

  it 'sets the job priority' do
    AsyncPriorityService.async(priority: 10)

    expect(AsyncPriorityService.servus_job_class.new.priority).to eq(10)
  end

  it 'evaluates the block in the job class context' do
    AsyncBlockService.async do
      queue_as :from_block
    end

    expect(AsyncBlockService.servus_job_class.new.queue_name).to eq('from_block')
  end

  it 'applies retry_on declared inside the block' do
    stub_const('BoomError', Class.new(StandardError))

    AsyncRetryService.async do
      retry_on BoomError, attempts: 5
    end

    handled = AsyncRetryService.servus_job_class.rescue_handlers.map(&:first)
    expect(handled).to include('BoomError')
  end

  it 'returns the configured job class' do
    expect(AsyncQueueService.async(queue: :default)).to eq(AsyncQueueService.servus_job_class)
  end

  describe 'inheritance' do
    before do
      stub_const('InheritedBoomError', Class.new(StandardError))

      AsyncInheritingBaseService.async(queue: :inherited, priority: 7) do
        retry_on InheritedBoomError, attempts: 4
      end
    end

    it "builds a service's job on its parent service's job" do
      expect(AsyncInheritingService.servus_job_class.superclass).to eq(AsyncInheritingBaseService.servus_job_class)
    end

    it 'builds the job of a service directly beneath Servus::Base on Servus::Extensions::Async::Job' do
      expect(AsyncFixtureService.servus_job_class.superclass).to eq(Servus::Extensions::Async::Job)
    end

    it "gives a subclass's job the queue its parent service set" do
      expect(AsyncInheritingService.servus_job_class.new.queue_name).to eq('inherited')
    end

    it "gives a subclass's job the priority its parent service set" do
      expect(AsyncInheritingService.servus_job_class.new.priority).to eq(7)
    end

    it "gives a subclass's job the retries its parent service declared" do
      handled = AsyncInheritingService.servus_job_class.rescue_handlers.map(&:first)
      expect(handled).to include('InheritedBoomError')
    end

    it "lets a subclass's own async override its parent's" do
      AsyncOverridingService.async(queue: :own)

      expect(AsyncOverridingService.servus_job_class.new.queue_name).to eq('own')
    end

    it "leaves the parent's job alone when a subclass overrides it" do
      AsyncOverridingService.async(queue: :own)

      expect(AsyncInheritingBaseService.servus_job_class.new.queue_name).to eq('inherited')
    end
  end

  describe 'the default queue' do
    around do |example|
      default = ActiveJob::Base.default_queue_name
      ActiveJob::Base.default_queue_name = 'configured_default'
      example.run
    ensure
      ActiveJob::Base.default_queue_name = default
    end

    it "follows ActiveJob's configured default when nothing sets one" do
      expect(AsyncUnconfiguredService.servus_job_class.new.queue_name).to eq('configured_default')
    end
  end
end
