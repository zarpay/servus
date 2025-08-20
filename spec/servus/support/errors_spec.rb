# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Servus::Support::Errors::ServiceError do
  let(:error) { described_class.new('error message') }

  it 'inherits from StandardError' do
    expect(described_class).to be < StandardError
  end

  it 'has a default message' do
    expect(described_class::DEFAULT_MESSAGE).to eq('An error occurred')
  end

  it 'has a message attribute' do
    expect(error.message).to eq('error message')
  end

  describe '#api_error' do
    it 'returns a default api error' do
      expect(described_class.new.api_error).to eq({ code: :bad_request, message: described_class::DEFAULT_MESSAGE })
    end

    it 'returns a custom api error' do
      expect(error.api_error).to eq({ code: :bad_request, message: 'error message' })
    end
  end
end
