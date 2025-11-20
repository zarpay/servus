# frozen_string_literal: true

require_relative 'example_extractor'

module Servus
  module Testing
    # Provides helper methods for extracting example values from service schemas.
    #
    # This module is designed to be included in test files (RSpec, Minitest, etc.)
    # to provide convenient access to schema example values. It's particularly useful
    # for generating test fixtures without manually maintaining separate factory files.
    #
    # The `servus_` prefix on method names prevents naming collisions with other
    # testing libraries and makes it clear these are Servus-specific helpers.
    #
    # @example Include in RSpec
    #   # spec/spec_helper.rb
    #   require 'servus/testing/example_builders'
    #
    #   RSpec.configure do |config|
    #     config.include Servus::Testing::ExampleBuilders
    #   end
    #
    # @example Include in Rails console (development)
    #   # config/environments/development.rb
    #   config.to_prepare do
    #     require 'servus/testing/example_builders'
    #
    #     if defined?(Rails::Console)
    #       include Servus::Testing::ExampleBuilders
    #     end
    #   end
    #
    # @example Use in tests
    #   RSpec.describe ProcessPayment::Service do
    #     it 'processes payment successfully' do
    #       args = servus_arguments_example(ProcessPayment::Service, amount: 50.0)
    #       result = ProcessPayment::Service.call(**args)
    #
    #       expect(result).to be_success
    #     end
    #   end
    module ExampleBuilders
      # Extracts example argument values from a service's schema.
      #
      # Looks for `example` or `examples` keywords in the service's arguments schema
      # and returns them as a hash ready to be passed to the service's `.call` method.
      #
      # @param service_class [Class] The service class to extract examples from
      # @param overrides [Hash] Optional values to override the schema examples
      # @return [Hash<Symbol, Object>] Hash of example argument values with symbolized keys
      #
      # @example Basic usage
      #   args = servus_arguments_example(ProcessPayment::Service)
      #   # => { user_id: 123, amount: 100.0, currency: 'USD' }
      #
      #   result = ProcessPayment::Service.call(**args)
      #
      # @example With overrides
      #   args = servus_arguments_example(ProcessPayment::Service, amount: 50.0, currency: 'EUR')
      #   # => { user_id: 123, amount: 50.0, currency: 'EUR' }
      #
      # @example In RSpec tests
      #   it 'processes different currencies' do
      #     %w[USD EUR GBP].each do |currency|
      #       result = ProcessPayment::Service.call(
      #         **servus_arguments_example(ProcessPayment::Service, currency: currency)
      #       )
      #       expect(result).to be_success
      #     end
      #   end
      #
      # @note Override keys can be strings or symbols; they'll be converted to symbols
      # @note Returns empty hash if service has no arguments schema defined
      def servus_arguments_example(service_class, overrides = {})
        extract_example_from(service_class, :arguments, overrides)
      end

      # Extracts example result values from a service's schema.
      #
      # Looks for `example` or `examples` keywords in the service's result schema
      # and returns them as a hash. Useful for validating service response structure
      # and expected data shapes in tests.
      #
      # @param service_class [Class] The service class to extract examples from
      # @param overrides [Hash] Optional values to override the schema examples
      # @return [Servus::Support::Response] Response object with example result data
      #
      # @example Basic usage
      #   expected = servus_result_example(ProcessPayment::Service)
      #   # => Servus::Support::Response with data:
      #   #    { transaction_id: 'txn_abc123', status: 'approved', amount_charged: 100.0 }
      #
      # @example Validate result structure
      #   result = ProcessPayment::Service.call(**servus_arguments_example(ProcessPayment::Service))
      #
      #   expect(result.data).to match(
      #     hash_including(servus_result_example(ProcessPayment::Service).data)
      #   )
      #
      # @example Check result has expected keys
      #   result = ProcessPayment::Service.call(**args)
      #   expected_keys = servus_result_example(ProcessPayment::Service).data.keys
      #
      #   expect(result.data.keys).to match_array(expected_keys)
      #
      # @example With overrides
      #   expected = servus_result_example(ProcessPayment::Service, status: 'pending').data
      #   # => { transaction_id: 'txn_abc123', status: 'pending', amount_charged: 100.0 }
      #
      # @note Override keys can be strings or symbols; they'll be converted to symbols
      # @note Returns empty hash if service has no result schema defined
      def servus_result_example(service_class, overrides = {})
        example = extract_example_from(service_class, :result, overrides)
        # Wrap in a successful Response object
        Servus::Support::Response.new(true, example, nil)
      end

      private

      # Helper method to extract and merge examples from schema
      #
      # @param service_class [Class] The service class to extract examples from
      # @param schema_type [Symbol] The type of schema (:arguments or :result)
      # @param overrides [Hash] Optional values to override the schema examples
      # @return [Hash<Symbol, Object>] Hash of example values with symbolized keys
      def extract_example_from(service_class, schema_type, overrides = {})
        examples = ExampleExtractor.extract(service_class, schema_type)
        examples.deep_merge(overrides.deep_symbolize_keys)
      end
    end
  end
end
