# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Servus::Events::Errors do
  describe described_class::AsyncBackendMissingError do
    subject(:error) { described_class.for(stub_const('Ledger::RecordEntry::Service', Class.new(Servus::Base))) }

    it 'names the service that could not be enqueued' do
      expect(error.message).to include('Ledger::RecordEntry::Service')
    end

    it 'says what is missing' do
      expect(error.message).to include('ActiveJob is not loaded')
    end

    it 'says what to do about it' do
      expect(error.message).to include('Require active_job')
    end

    # Rescuing these as service failures would render a job-backend problem to
    # an API caller as though it were a business outcome.
    it 'is not a ServiceError' do
      expect(error).not_to be_a(Servus::Support::Errors::ServiceError)
    end
  end

  describe described_class::AnonymousServiceError do
    subject(:error) { described_class.for(Class.new(Servus::Base)) }

    it 'explains why a name is required' do
      expect(error.message).to include('resolves jobs by class name')
    end

    it 'says what to do about it' do
      expect(error.message).to include('assigned')
      expect(error.message).to include('constant')
    end
  end

  it 'gives both errors a common ancestor' do
    expect(described_class::AsyncBackendMissingError.ancestors).to include(described_class::Error)
    expect(described_class::AnonymousServiceError.ancestors).to include(described_class::Error)
  end
end
