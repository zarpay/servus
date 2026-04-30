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

    context 'when rescue_from is configured with a block' do
      describe 'returning failure with custom message' do
        class TestServiceWithBlockFailure < MixinService
          rescue_from CustomError1 do |e|
            failure("Custom failure: #{e.message}")
          end
        end

        it 'returns a failure response with custom message' do
          result = TestServiceWithBlockFailure.call(error: 1)

          expect(result.success?).to be false
          expect(result.error).to be_a(Servus::Support::Errors::ServiceError)
          expect(result.error.message).to eq('Custom failure: custom error 1')
        end
      end

      describe 'returning success despite exception' do
        class TestServiceWithBlockSuccess < MixinService
          rescue_from CustomError1 do |e|
            # Log the error but continue successfully
            success({ recovered: true, original_error: e.message })
          end
        end

        it 'returns a success response despite the exception' do
          result = TestServiceWithBlockSuccess.call(error: 1)

          expect(result.success?).to be true
          expect(result.data).to eq({ recovered: true, original_error: 'custom error 1' })
        end
      end

      describe 'with custom error type in block' do
        class TestServiceWithBlockAndErrorType < MixinService
          rescue_from CustomError1 do |e|
            failure(
              "Validation failed: #{e.message}",
              type: Servus::Support::Errors::ValidationError
            )
          end
        end

        it 'returns failure with specified error type' do
          result = TestServiceWithBlockAndErrorType.call(error: 1)

          expect(result.success?).to be false
          expect(result.error).to be_a(Servus::Support::Errors::ValidationError)
          expect(result.error.message).to eq('Validation failed: custom error 1')
        end
      end

      describe 'with multiple rescue_from blocks' do
        class TestServiceWithMultipleBlocks < MixinService
          rescue_from CustomError1 do |e|
            failure("Error 1: #{e.message}")
          end

          rescue_from CustomError2 do |e|
            failure("Error 2: #{e.message}")
          end
        end

        it 'handles first error type correctly' do
          result = TestServiceWithMultipleBlocks.call(error: 1)

          expect(result.success?).to be false
          expect(result.error.message).to eq('Error 1: custom error 1')
        end

        it 'handles second error type correctly' do
          result = TestServiceWithMultipleBlocks.call(error: 2)

          expect(result.success?).to be false
          expect(result.error.message).to eq('Error 2: custom error 2')
        end
      end

      describe 'backwards compatibility' do
        class TestServiceMixedStyle < MixinService
          # Old style without block
          rescue_from CustomError1, use: Servus::Support::Errors::ValidationError

          # New style with block
          rescue_from CustomError2 do |e|
            failure("Block handled: #{e.message}")
          end
        end

        it 'handles non-block rescue_from as before' do
          result = TestServiceMixedStyle.call(error: 1)

          expect(result.success?).to be false
          expect(result.error).to be_a(Servus::Support::Errors::ValidationError)
          expect(result.error.message).to eq('[MixinService::CustomError1]: custom error 1')
        end

        it 'handles block rescue_from with new behavior' do
          result = TestServiceMixedStyle.call(error: 2)

          expect(result.success?).to be false
          expect(result.error.message).to eq('Block handled: custom error 2')
        end
      end
    end
  end
end
