# frozen_string_literal: true

module Servus
  module Support
    class Validator
      # Class-level schema cache
      @schema_cache = {}

      # Validate service arguments against schema
      def self.validate_arguments!(service_class, args)
        schema = load_schema(service_class, "arguments")
        return true unless schema # Skip validation if no schema exists

        serialized_result = args.as_json
        validation_errors = JSON::Validator.fully_validate(schema, serialized_result)

        if validation_errors.any?
          error_message = "Invalid arguments for #{service_class.name}: #{validation_errors.join(", ")}"
          raise Servus::Base::ValidationError, error_message
        end

        true
      end

      # Validate service result against schema
      def self.validate_result!(service_class, result)
        return result unless result.success?

        schema = load_schema(service_class, "result")
        return result unless schema # Skip validation if no schema exists

        serialized_result = result.data.as_json
        validation_errors = JSON::Validator.fully_validate(schema, serialized_result)

        if validation_errors.any?
          error_message = "Invalid result structure from #{service_class.name}: #{validation_errors.join(", ")}"
          raise Servus::Base::ValidationError, error_message
        end

        result
      end

      # Load schema from file with caching
      def self.load_schema(service_class, type)
        # Get service path based on class name (e.g., "process_payment" from "Servus::ProcessPayment::Service")
        service_namespace = service_class.name.split("::")[..-2].map do |s|
          s.gsub(/([a-z])([A-Z])/, '\1_\2').downcase
        end.join("/")
        schema_path = Servus.config.schema_path_for(service_namespace, type)

        # Return from cache if available
        return @schema_cache[schema_path] if @schema_cache.key?(schema_path)

        inline_schema_constant_name = "#{service_class}::#{type.upcase}_SCHEMA"
        inline_schema_constant = Object.const_defined?(inline_schema_constant_name) ? Object.const_get(inline_schema_constant_name) : nil

        if inline_schema_constant
          @schema_cache[schema_path] =
            inline_schema_constant.respond_to?(:deep_stringify_keys) ? inline_schema_constant.deep_stringify_keys : inline_schema_constant
        elsif File.exist?(schema_path)
          @schema_cache[schema_path] = JSON.parse(File.read(schema_path))
        else
          # Cache nil result to avoid checking file system again
          @schema_cache[schema_path] = nil
        end

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
    end
  end
end
