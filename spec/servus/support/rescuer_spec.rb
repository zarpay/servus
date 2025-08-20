# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Servus::Support::Rescuer do
  # A standard service to be extended
  class MixinService < Servus::Base
    class CustomError1 < StandardError; end
    class CustomError2 < StandardError; end

    def initialize(error:)
      @error = error
    end

    def call
      if @error == 1
        a_method_that_raises_custom_error
      else
        another_method_that_raises_custom_error
      end
    end

    def a_method_that_raises_custom_error
      raise StandardError
    rescue StandardError
      raise CustomError1, 'custom error 1'
    end

    def another_method_that_raises_custom_error
      raise StandardError
    rescue StandardError
      raise CustomError2, 'custom error 2'
    end
  end

  describe 'rescue_from' do
    context 'when rescue_from is configured' do
      class TestServiceV3 < MixinService
        rescue_from CustomError1
      end
      it 'returns a failure response with custom error 1' do
        result = TestServiceV3.call(error: 1)

        expect(result.success?).to be false
        expect(result.error).to be_a(Servus::Support::Errors::ServiceError)
        expect(result.error.message).to eq('[MixinService::CustomError1]: custom error 1')
      end
    end

    context 'when rescue_from is configured with multiple errors' do
      class TestServiceV4 < MixinService
        rescue_from CustomError1, CustomError2
      end
      it 'returns a failure response with custom error 1' do
        result = TestServiceV4.call(error: 1)

        expect(result.success?).to be false
        expect(result.error).to be_a(Servus::Support::Errors::ServiceError)
        expect(result.error.message).to eq('[MixinService::CustomError1]: custom error 1')
      end

      it 'returns a failure response with custom error 2' do
        result = TestServiceV4.call(error: 2)

        expect(result.success?).to be false
        expect(result.error).to be_a(Servus::Support::Errors::ServiceError)
        expect(result.error.message).to eq('[MixinService::CustomError2]: custom error 2')
      end
    end

    context 'when rescue_from is configured to use a custom error type' do
      class TestServiceV5 < MixinService
        rescue_from CustomError1, use: Servus::Support::Errors::ValidationError
      end
      it 'returns a failure response with custom error 1' do
        result = TestServiceV5.call(error: 1)

        expect(result.success?).to be false
        expect(result.error).to be_a(Servus::Support::Errors::ValidationError)
        expect(result.error.message).to eq('[MixinService::CustomError1]: custom error 1')
      end
    end
  end
end
