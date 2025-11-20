# frozen_string_literal: true

module Servus
  module Support
    # Handles JSON Schema validation for service arguments and results.
    #
    # The Validator class provides automatic validation of service inputs and outputs
    # against JSON Schema definitions. Schemas can be defined as inline constants
    # (ARGUMENTS_SCHEMA, RESULT_SCHEMA) or as external JSON files.
    #
    # @example Inline schema validation
    #   class MyService < Servus::Base
    #     ARGUMENTS_SCHEMA = {
    #       type: "object",
    #       required: ["user_id"],
    #       properties: {
    #         user_id: { type: "integer" }
    #       }
    #     }
    #   end
    #
    # @example File-based schema validation
    #   # app/schemas/services/my_service/arguments.json
    #   # { "type": "object", "required": ["user_id"], ... }
    #
    # @see https://json-schema.org/specification.html
    class Validator
      # @api private
      @schema_cache = {}

      # Validates service arguments against the ARGUMENTS_SCHEMA.
      #
      # Checks arguments against either an inline ARGUMENTS_SCHEMA constant or
      # a file-based schema at app/schemas/services/namespace/arguments.json.
      # Validation is skipped if no schema is defined.
      #
      # @param service_class [Class] the service class being validated
      # @param args [Hash] keyword arguments passed to the service
      # @return [Boolean] true if validation passes
      # @raise [Servus::Support::Errors::ValidationError] if arguments fail validation
      #
      # @example
      #   Validator.validate_arguments!(MyService, { user_id: 123 })
      #
      # @api private
      def self.validate_arguments!(service_class, args)
        schema = load_schema(service_class, 'arguments')
        return true unless schema # Skip validation if no schema exists

        serialized_result = args.as_json
        validation_errors = JSON::Validator.fully_validate(schema, serialized_result)

        if validation_errors.any?
          error_message = "Invalid arguments for #{service_class.name}: #{validation_errors.join(', ')}"
          raise Servus::Base::ValidationError, error_message
        end

        true
      end

      # Validates service result data against the RESULT_SCHEMA.
      #
      # Checks the result.data against either an inline RESULT_SCHEMA constant or
      # a file-based schema at app/schemas/services/namespace/result.json.
      # Only validates successful responses; failures are skipped.
      #
      # @param service_class [Class] the service class being validated
      # @param result [Servus::Support::Response] the response object to validate
      # @return [Servus::Support::Response] the original result if validation passes
      # @raise [Servus::Support::Errors::ValidationError] if result data fails validation
      #
      # @example
      #   Validator.validate_result!(MyService, response)
      #
      # @api private
      def self.validate_result!(service_class, result)
        return result unless result.success?

        schema = load_schema(service_class, 'result')
        return result unless schema # Skip validation if no schema exists

        serialized_result = result.data.as_json
        validation_errors = JSON::Validator.fully_validate(schema, serialized_result)

        if validation_errors.any?
          error_message = "Invalid result structure from #{service_class.name}: #{validation_errors.join(', ')}"
          raise Servus::Base::ValidationError, error_message
        end

        result
      end

      # Loads and caches a schema for a service.
      #
      # Implements a three-tier lookup strategy:
      # 1. Check for schema defined via DSL method (service_class.arguments_schema/result_schema)
      # 2. Check for inline constant (ARGUMENTS_SCHEMA or RESULT_SCHEMA)
      # 3. Fall back to JSON file in app/schemas/services/namespace/type.json
      #
      # Schemas are cached after first load for performance.
      #
      # @param service_class [Class] the service class
      # @param type [String] schema type ("arguments" or "result")
      # @return [Hash, nil] the schema hash, or nil if no schema found
      #
      # @api private
      # rubocop:disable Metrics/MethodLength
      def self.load_schema(service_class, type)
        # Get service path based on class name (e.g., "process_payment" from "Servus::ProcessPayment::Service")
        service_namespace = parse_service_namespace(service_class)
        schema_path = Servus.config.schema_path_for(service_namespace, type)

        # Return from cache if available
        return @schema_cache[schema_path] if @schema_cache.key?(schema_path)

        # Check for DSL-defined schema first
        dsl_schema = if type == 'arguments'
                       service_class.arguments_schema
                     else
                       service_class.result_schema
                     end

        inline_schema_constant_name = "#{service_class}::#{type.upcase}_SCHEMA"
        inline_schema_constant = if Object.const_defined?(inline_schema_constant_name)
                                   Object.const_get(inline_schema_constant_name)
                                 end

        @schema_cache[schema_path] = fetch_schema_from_sources(dsl_schema, inline_schema_constant, schema_path)
        @schema_cache[schema_path]
      end
      # rubocop:enable Metrics/MethodLength

      # Clears the schema cache.
      #
      # Useful in development when schema files are modified, or in tests
      # to ensure fresh schema loading between test cases.
      #
      # @return [Hash] empty hash
      #
      # @example In a test suite
      #   before(:each) do
      #     Servus::Support::Validator.clear_cache!
      #   end
      def self.clear_cache!
        @schema_cache = {}
      end

      # Returns the current schema cache.
      #
      # @return [Hash] cache mapping schema paths to loaded schemas
      # @api private
      def self.cache
        @schema_cache
      end

      # Fetches schema from DSL, inline constant, or file.
      #
      # Implements the schema resolution precedence:
      # 1. DSL-defined schema (if provided)
      # 2. Inline constant (if provided)
      # 3. File at schema_path (if exists)
      # 4. nil (no schema found)
      #
      # @param dsl_schema [Hash, nil] schema from DSL method (e.g., schema arguments: Hash)
      # @param inline_schema_constant [Hash, nil] inline schema constant (e.g., ARGUMENTS_SCHEMA)
      # @param schema_path [String] file path to external schema JSON
      # @return [Hash, nil] schema with indifferent access, or nil if not found
      #
      # @api private
      def self.fetch_schema_from_sources(dsl_schema, inline_schema_constant, schema_path)
        if dsl_schema
          dsl_schema.with_indifferent_access
        elsif inline_schema_constant
          inline_schema_constant.with_indifferent_access
        elsif File.exist?(schema_path)
          JSON.load_file(schema_path).with_indifferent_access
        end
      end

      # Converts service class name to file path namespace.
      #
      # Transforms a class name like "Services::ProcessPayment::Service" into
      # "services/process_payment" for locating schema files.
      #
      # @param service_class [Class] the service class
      # @return [String] underscored namespace path
      #
      # @example
      #   parse_service_namespace(Services::ProcessPayment::Service)
      #   # => "services/process_payment"
      #
      # @api private
      def self.parse_service_namespace(service_class)
        service_class.name.split('::')[..-2].map do |s|
          s.gsub(/([a-z])([A-Z])/, '\1_\2').downcase
        end.join('/')
      end
    end
  end
end
