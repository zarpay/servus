# frozen_string_literal: true

module Servus
  module Support
    # Validates arguments and results
    class Validator
      # Class-level schema cache
      @schema_cache = {}

      # Validate service arguments against schema
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

      # Validate service result against schema
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

      # Load schema from file with caching
      def self.load_schema(service_class, type)
        # Get service path based on class name (e.g., "process_payment" from "Servus::ProcessPayment::Service")
        service_namespace = parse_service_namespace(service_class)
        schema_path = Servus.config.schema_path_for(service_namespace, type)

        # Return from cache if available
        return @schema_cache[schema_path] if @schema_cache.key?(schema_path)

        inline_schema_constant_name = "#{service_class}::#{type.upcase}_SCHEMA"
        inline_schema_constant = if Object.const_defined?(inline_schema_constant_name)
                                   Object.const_get(inline_schema_constant_name)
                                 end

        @schema_cache[schema_path] = fetch_schema_from_sources(inline_schema_constant, schema_path)
        @schema_cache[schema_path]
      end

      # Clear the schema cache (useful for testing or development)
      def self.clear_cache!
        @schema_cache = {}
      end

      # Returns the schema cache
      def self.cache
        @schema_cache
      end

      # Fetches the schema from the sources
      #
      # This method checks if the schema is defined as an inline constant or if it exists as a file. The
      # schema is then symbolized and returned. If the schema is not found, nil is returned.
      #
      # @param inline_schema_constant [Hash, String] the inline schema constant to process
      # @param schema_path [String] the path to the schema file
      # @return [Hash] the processed inline schema constant
      def self.fetch_schema_from_sources(inline_schema_constant, schema_path)
        if inline_schema_constant
          inline_schema_constant.with_indifferent_access
        elsif File.exist?(schema_path)
          JSON.load_file(schema_path).with_indifferent_access
        end
      end

      # Parses the service namespace from the service class name
      #
      # @param service_class [Class] the service class to parse
      # @return [String] the service namespace
      def self.parse_service_namespace(service_class)
        service_class.name.split('::')[..-2].map do |s|
          s.gsub(/([a-z])([A-Z])/, '\1_\2').downcase
        end.join('/')
      end
    end
  end
end
