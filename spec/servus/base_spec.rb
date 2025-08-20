# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Servus::Base do
  # Example service for testing
  class TestServiceV2 < Servus::Base
    def initialize(should_succeed: true, data: nil)
      @should_succeed = should_succeed
      @data = data
    end

    def call
      if @should_succeed
        success(@data)
      else
        failure('error message')
      end
    end

    def call_error
      error!('error message')
    end
  end

  describe '.call' do
    let(:custom_data) { { key: 'value' } }

    it 'instantiates the service and calls #call' do
      result = TestServiceV2.call(should_succeed: true)
      expect(result).to be_success
    end

    it 'passes arguments to initialize' do
      result = TestServiceV2.call(should_succeed: true, data: custom_data)
      expect(result.data).to eq(custom_data)
    end

    it 'validates arguments using Validator' do
      expect(Servus::Support::Validator).to receive(:validate_arguments!)
        .with(TestServiceV2, { should_succeed: true, data: custom_data })
        .exactly(1).times

      TestServiceV2.call(should_succeed: true, data: custom_data)
    end

    it 'returns an Servus::Support::Response object' do
      result = TestServiceV2.call(should_succeed: true, data: custom_data)
      expect(result).to be_a(Servus::Support::Response)
    end

    it 'validates result using Validator' do
      expect(Servus::Support::Validator).to receive(:validate_result!)
        .with(TestServiceV2, an_instance_of(Servus::Support::Response))
        .exactly(1).times

      TestServiceV2.call(should_succeed: true, data: custom_data)
    end

    it 'calls log_call on Logger with correct arguments' do
      data = { should_succeed: true, data: custom_data }

      allow(Servus::Support::Logger).to receive(:log_call)
        .with(TestServiceV2, data).exactly(1).times

      TestServiceV2.call(should_succeed: true, data: custom_data)

      expect(Servus::Support::Logger).to have_received(:log_call)
        .with(TestServiceV2, data).exactly(1).times
    end

    it 'calls log_result on Logger with correct arguments' do
      allow(Servus::Support::Logger).to receive(:log_result)
        .with(TestServiceV2, an_instance_of(Servus::Support::Response), an_instance_of(Float))
        .exactly(1).times

      TestServiceV2.call(should_succeed: true, data: custom_data)

      expect(Servus::Support::Logger).to have_received(:log_result)
        .with(TestServiceV2, an_instance_of(Servus::Support::Response), an_instance_of(Float))
        .exactly(1).times
    end

    it 'calls log_failure on Logger with correct arguments' do
      allowed_instance = an_instance_of(Servus::Support::Errors::ServiceError)

      allow(Servus::Support::Logger).to receive(:log_failure)
        .with(TestServiceV2, allowed_instance, an_instance_of(Float)).exactly(1).times

      TestServiceV2.call(should_succeed: false)

      expect(Servus::Support::Logger).to have_received(:log_failure)
        .with(TestServiceV2, allowed_instance, an_instance_of(Float)).exactly(1).times
    end

    it 'calls log_exception on Logger with correct arguments' do
      allow(Servus::Support::Logger).to receive(:log_exception)
        .with(TestServiceV2, an_instance_of(StandardError)).exactly(1).times

      # Raise an exception to test the error handling
      allow(Time).to receive(:now).and_raise(StandardError)

      # Call the service and expect it to raise an exception
      expect { TestServiceV2.call(should_succeed: true, data: custom_data) }.to raise_error(StandardError)

      expect(Servus::Support::Logger).to have_received(:log_exception)
        .with(TestServiceV2, an_instance_of(StandardError)).exactly(1).times
    end
  end

  describe '#success' do
    let(:test_cases) { [nil, 'success data', { key: 'value' }, %w[array data], 123, true] }

    it 'returns an Servus::Support::Response with success status' do
      result = TestServiceV2.call(should_succeed: true, data: 'success data')

      expect(result).to be_a(Servus::Support::Response)
      expect(result.error).to be_nil
      expect(result.success?).to be true
      expect(result.data).to eq('success data')
    end

    it 'can handle different types of data' do
      test_cases.each do |data|
        result = TestServiceV2.call(should_succeed: true, data: data)
        expect(result.data).to eq(data)
      end
    end
  end

  describe '#failure' do
    let(:result) { TestServiceV2.call(should_succeed: false) }

    it 'is a Servus::Support::Response with failure status' do
      expect(result).to be_a(Servus::Support::Response)
      expect(result.data).to be_nil
      expect(result.success?).to be false
      expect(result.error).to be_a(Servus::Support::Errors::ServiceError)
    end

    it 'has a service error and message' do
      expect(result.error.message).to eq('error message')
    end

    it 'has an api error and message' do
      expect(result.error.api_error).to eq({ code: :bad_request, message: 'error message' })
    end

    it 'uses the default error type and default message' do
      result = TestServiceV2.new.failure

      expect(result.error).to be_a(Servus::Support::Errors::ServiceError)
      expect(result.error.message).to eq('An error occurred')
    end

    it 'uses the specified error type and default message' do
      result = TestServiceV2.new.failure(type: Servus::Support::Errors::ValidationError)

      expect(result.error).to be_a(Servus::Support::Errors::ValidationError)
      expect(result.error.message).to eq('Validation failed')
    end

    it 'uses the specified error type and specified message' do
      result = TestServiceV2.new.failure('Custom message', type: Servus::Support::Errors::NotFoundError)

      expect(result.error).to be_a(Servus::Support::Errors::NotFoundError)
      expect(result.error.message).to eq('Custom message')
    end

    it 'uses the default error type and specified message' do
      result = TestServiceV2.new.failure('Custom message')

      expect(result.error).to be_a(Servus::Support::Errors::ServiceError)
      expect(result.error.message).to eq('Custom message')
    end
  end

  describe 'inheritance' do
    it 'allows child classes to access success method' do
      result = TestServiceV2.call(should_succeed: true)
      expect(result.success?).to be true
    end

    it 'allows child classes to access failure method' do
      result = TestServiceV2.call(should_succeed: false)
      expect(result.success?).to be false
    end

    it 'allows child classes to access error method' do
      expect { TestServiceV2.new.call_error }.to raise_error(Servus::Support::Errors::ServiceError, 'error message')
    end
  end
end
