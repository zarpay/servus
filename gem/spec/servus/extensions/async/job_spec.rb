# frozen_string_literal: true

require 'spec_helper'
require 'active_job'

require 'servus/extensions/async/ext'

RSpec.describe Servus::Extensions::Async::Job, type: :job do
  before { Servus::Base.extend(Servus::Extensions::Async::Call) }

  let(:job) { AsyncEmailService.servus_job_class.new }

  it 'invokes its bound service with the given arguments' do
    expect(AsyncEmailService).to receive(:call).with(
      a: 1,
      b: 2
    )

    job.perform(
      a: 1,
      b: 2
    )
  end

  it 'carries a reference back to the service it runs' do
    expect(AsyncEmailService.servus_job_class.servus_service).to eq(AsyncEmailService)
  end
end
