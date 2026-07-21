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
end
