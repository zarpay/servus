# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Servus::Testing::ExampleBuilders do
  # Include the module to test the helper methods
  include Servus::Testing::ExampleBuilders

  # Test service classes
  module ExampleBuildersTest
    class PaymentService < Servus::Base
      schema(
        arguments: {
          type: 'object',
          required: %w[user_id amount],
          properties: {
            user_id: { type: 'integer', example: 123 },
            amount: { type: 'number', example: 100.0 },
            currency: { type: 'string', example: 'USD' },
            payment_method: { type: 'string', example: 'credit_card' }
          }
        },
        result: {
          type: 'object',
          properties: {
            transaction_id: { type: 'string', example: 'txn_abc123' },
            status: { type: 'string', example: 'approved' },
            amount_charged: { type: 'number', example: 100.0 }
          }
        }
      )

      def initialize(user_id:, amount:, currency: 'USD', payment_method: 'credit_card')
        @user_id = user_id
        @amount = amount
        @currency = currency
        @payment_method = payment_method
      end

      def call
        success({
                  transaction_id: 'txn_xyz',
                  status: 'approved',
                  amount_charged: @amount
                })
      end
    end

    class NoSchemaService < Servus::Base
      def initialize(name:)
        @name = name
      end

      def call
        success({ result: @name })
      end
    end
  end

  before { Servus::Support::Validator.clear_cache! }

  describe '#servus_arguments_example' do
    context 'with service that has argument schema with examples' do
      it 'returns hash of example argument values' do
        result = servus_arguments_example(ExampleBuildersTest::PaymentService)

        expect(result).to eq({
                               user_id: 123,
                               amount: 100.0,
                               currency: 'USD',
                               payment_method: 'credit_card'
                             })
      end
    end

    context 'with overrides' do
      it 'merges overrides with example values' do
        result = servus_arguments_example(
          ExampleBuildersTest::PaymentService,
          amount: 50.0,
          currency: 'EUR'
        )

        expect(result).to eq({
                               user_id: 123,
                               amount: 50.0,
                               currency: 'EUR',
                               payment_method: 'credit_card'
                             })
      end

      it 'allows adding new keys not in schema' do
        result = servus_arguments_example(
          ExampleBuildersTest::PaymentService,
          extra_field: 'extra_value'
        )

        expect(result).to include(
          user_id: 123,
          extra_field: 'extra_value'
        )
      end

      it 'converts string keys in overrides to symbols' do
        result = servus_arguments_example(
          ExampleBuildersTest::PaymentService,
          'amount' => 75.0
        )

        expect(result[:amount]).to eq(75.0)
        expect(result.keys).to all(be_a(Symbol))
      end

      it 'handles empty overrides hash' do
        result = servus_arguments_example(ExampleBuildersTest::PaymentService, {})

        expect(result).to eq({
                               user_id: 123,
                               amount: 100.0,
                               currency: 'USD',
                               payment_method: 'credit_card'
                             })
      end
    end

    context 'with service that has no schema' do
      it 'returns empty hash when no schema defined' do
        result = servus_arguments_example(ExampleBuildersTest::NoSchemaService)
        expect(result).to eq({})
      end

      it 'returns only overrides when no schema defined' do
        result = servus_arguments_example(
          ExampleBuildersTest::NoSchemaService,
          name: 'Test'
        )
        expect(result).to eq({ name: 'Test' })
      end
    end

    context 'integration with service call' do
      it 'can be used directly with service.call' do
        args = servus_arguments_example(ExampleBuildersTest::PaymentService)
        result = ExampleBuildersTest::PaymentService.call(**args)

        expect(result).to be_success
        expect(result.data).to include(:transaction_id, :status, :amount_charged)
      end

      it 'works with splat operator and overrides' do
        result = ExampleBuildersTest::PaymentService.call(
          **servus_arguments_example(ExampleBuildersTest::PaymentService, amount: 250.0)
        )

        expect(result).to be_success
        expect(result.data[:amount_charged]).to eq(250.0)
      end
    end

    context 'deep merge overrides' do
      class NestedService < Servus::Base
        schema(
          arguments: {
            type: 'object',
            properties: {
              user: {
                type: 'object',
                properties: {
                  id: { type: 'integer', example: 1 },
                  profile: {
                    type: 'object',
                    properties: {
                      name: { type: 'string', example: 'Alice' },
                      age: { type: 'integer', example: 30 }
                    }
                  }
                }
              }
            }
          }
        )

        def initialize(user:)
          @user = user
        end

        def call
          success({ user: @user })
        end
      end

      it 'deep merges nested overrides' do
        result = servus_arguments_example(
          NestedService,
          user: {
            profile: {
              age: 35
            }
          }
        )

        expect(result).to eq({
                               user: {
                                 id: 1,
                                 profile: {
                                   name: 'Alice',
                                   age: 35
                                 }
                               }
                             })
      end
    end
  end

  describe '#servus_result_example' do
    context 'with service that has result schema with examples' do
      it 'returns hash of example result values' do
        result = servus_result_example(ExampleBuildersTest::PaymentService)

        expect(result).to be_a(Servus::Support::Response)
        expect(result.success?).to be(true)
        expect(result.data).to eq({
                                    transaction_id: 'txn_abc123',
                                    status: 'approved',
                                    amount_charged: 100.0
                                  })
      end

      it 'returns hash with symbolized keys' do
        result = servus_result_example(ExampleBuildersTest::PaymentService)
        expect(result.data.keys).to all(be_a(Symbol))
      end
    end

    context 'with overrides' do
      it 'merges overrides with example values' do
        result = servus_result_example(
          ExampleBuildersTest::PaymentService,
          status: 'pending',
          amount_charged: 75.0
        )

        expect(result.data).to eq({
                                    transaction_id: 'txn_abc123',
                                    status: 'pending',
                                    amount_charged: 75.0
                                  })
      end

      it 'converts string keys in overrides to symbols' do
        result = servus_result_example(
          ExampleBuildersTest::PaymentService,
          'status' => 'declined'
        )

        expect(result.data[:status]).to eq('declined')
        expect(result.data.keys).to all(be_a(Symbol))
      end
    end

    context 'with service that has no result schema' do
      it 'returns empty hash when no schema defined' do
        result = servus_result_example(ExampleBuildersTest::NoSchemaService)
        expect(result.data).to eq({})
      end

      it 'returns only overrides when no schema defined' do
        result = servus_result_example(
          ExampleBuildersTest::NoSchemaService,
          custom_field: 'value'
        )
        expect(result.data).to eq({ custom_field: 'value' })
      end
    end

    context 'for result validation in tests' do
      it 'can be used to validate result structure' do
        result = ExampleBuildersTest::PaymentService.call(
          **servus_arguments_example(ExampleBuildersTest::PaymentService)
        )

        example_result = servus_result_example(ExampleBuildersTest::PaymentService)

        # Check that result has all expected keys
        expect(result.data.keys).to match_array(example_result.data.keys)
      end

      it 'can be used with RSpec matchers' do
        result = ExampleBuildersTest::PaymentService.call(
          **servus_arguments_example(ExampleBuildersTest::PaymentService)
        )

        expected_keys = servus_result_example(ExampleBuildersTest::PaymentService).data.keys

        expect(result.data).to include(*expected_keys)
      end
    end
  end

  describe 'module inclusion' do
    it 'makes methods available when included' do
      expect(self).to respond_to(:servus_arguments_example)
      expect(self).to respond_to(:servus_result_example)
    end

    it 'does not pollute Object' do
      expect(Object.new).not_to respond_to(:servus_arguments_example)
      expect(Object.new).not_to respond_to(:servus_result_example)
    end
  end
end
