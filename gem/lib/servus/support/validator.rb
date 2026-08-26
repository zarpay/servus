# frozen_string_literal: true

module Servus
  module Support
    # Validates service arguments and results, and event payloads, against the
    # JSON schemas declared with the +schema+ DSL.
    #
    # Arguments are validated before +call+ runs, so a service body can trust
    # the shape of its inputs. Result data is validated after it returns, so a
    # service that stops honouring its own contract fails loudly rather than
    # passing the wrong shape to its callers. Both raise
    # {Servus::Support::Errors::ValidationError}, which signals a bug — in the
    # caller for arguments, in the service itself for results — and is not
    # meant to be rescued.
    #
    # Schemas come from the +schema+ DSL and nowhere else. The class-level
    # readers resolve any +$ref+s against {Servus::Schema}, so what arrives
    # here is always a self-contained schema.
    #
    # @example
    #   class MyService < Servus::Base
    #     schema arguments: { type: 'object', required: ['user_id'] }
    #   end
    #
    # @see Servus::Base.schema
    # @see Servus::Schema
    # @see https://json-schema.org/specification.html
    class Validator
      # Schema kinds that may be requested from {.load_schema}.
      #
      # @api private
      SCHEMA_TYPES = %w[arguments result failure payload].freeze

      # @api private
      @schema_cache = {}

      # Validates service arguments against the service's arguments schema.
      #
      # @param service_class [Class] the service class being validated
      # @param args [Hash] keyword arguments passed to the service
      # @return [Boolean] true if validation passes
      # @raise [Servus::Support::Errors::ValidationError] if arguments fail validation
      # @raise [Servus::Support::Errors::SchemaRequiredError] if no schema is
      #   declared and +require_service_arguments_schema+ is enabled
      #
      # @example
      #   Validator.validate_arguments!(MyService, { user_id: 123 })
      #
      # @api private
      def self.validate_arguments!(service_class, args)
        schema = load_schema(service_class, 'arguments')
        enforce_schema_presence!(schema, service_class, :require_service_arguments_schema)
        return true unless schema

        validate_data_against_schema!(args, schema, "Invalid arguments for #{service_class.name}")

        true
      end

      # Validates service result data against the appropriate schema.
      #
      # For successful responses, validates against the +result+ schema.
      # For failure responses with data, validates against the +failure+ schema.
      # Failure responses without data are skipped.
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
        schema, schema_type = result_schema_for(service_class, result)
        return result unless schema

        validate_data_against_schema!(
          result.data,
          schema,
          "Invalid #{schema_type} structure from #{service_class.name}"
        )

        result
      end

      # Resolves the schema and type label for a service result.
      #
      # @param service_class [Class] the service class
      # @param result [Servus::Support::Response] the response object
      # @return [Array(Hash, String), Array(nil, nil)] the schema and type label
      #
      # @api private
      def self.result_schema_for(service_class, result)
        if result.success?
          schema = load_schema(service_class, 'result')
          enforce_schema_presence!(schema, service_class, :require_service_result_schema)
          [schema, 'result']
        elsif result.data
          [load_schema(service_class, 'failure'), 'failure']
        end
      end

      # Validates an event payload against the event's payload schema.
      #
      # @param event_class [Class] the Event subclass
      # @param payload [Hash] the event payload to validate
      # @return [Boolean] true if validation passes
      # @raise [Servus::Support::Errors::ValidationError] if payload fails validation
      #
      # @example
      #   Validator.validate_event_payload!(UserCreated, { user_id: 123 })
      #
      # @api private
      def self.validate_event_payload!(event_class, payload)
        schema = load_schema(event_class, 'payload')
        enforce_schema_presence!(schema, event_class, :require_event_payload_schema)
        return true unless schema

        validate_data_against_schema!(
          payload,
          schema,
          "Invalid payload for event :#{event_class.event_name}"
        )

        true
      end

      # Returns a class's compiled schema of the given kind.
      #
      # Cached per class and kind. The underlying compilation is also memoized
      # on the class itself and rebuilds when {Servus::Schema} changes, so this
      # cache exists to skip the lookup, not to hold compilation results.
      #
      # @param klass [Class] a {Servus::Base} or {Servus::Event} subclass
      # @param type [String, Symbol] one of {SCHEMA_TYPES}
      # @return [Hash, nil] the compiled schema, or nil if none is declared
      # @raise [ArgumentError] if +type+ is not a known schema kind
      #
      # @api private
      def self.load_schema(klass, type)
        type = type.to_s

        unless SCHEMA_TYPES.include?(type)
          raise ArgumentError, "unknown schema type #{type.inspect}. Valid: #{SCHEMA_TYPES.join(', ')}."
        end

        key = [klass, type]
        return @schema_cache[key] if @schema_cache.key?(key)

        @schema_cache[key] = klass.public_send(:"#{type}_schema")
      end

      # Clears the schema cache.
      #
      # Useful in tests, and in development after changing a schema. Registry
      # changes invalidate compiled schemas on their own, so this is rarely
      # needed in application code.
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
      # @return [Hash] cache mapping [class, type] pairs to compiled schemas
      # @api private
      def self.cache
        @schema_cache
      end

      # Serializes data and validates it against a JSON schema.
      #
      # @param data [Object] the data to validate
      # @param schema [Hash] the JSON schema to validate against
      # @param message_prefix [String] prefix for the error message on failure
      # @return [void]
      # @raise [Servus::Support::Errors::ValidationError] if data fails validation
      #
      # @api private
      def self.validate_data_against_schema!(data, schema, message_prefix)
        errors = JSON::Validator.fully_validate(schema, data.as_json)
        return if errors.empty?

        raise Servus::Base::ValidationError, "#{message_prefix}: #{errors.join(', ')}"
      end

      # Raises if a schema is absent and the corresponding config flag is on.
      #
      # @param schema [Hash, nil] the loaded schema
      # @param klass [Class] the service or Event class
      # @param config_flag [Symbol] the config method to check
      # @return [Hash, nil] the schema, unchanged
      # @raise [Servus::Support::Errors::SchemaRequiredError] if schema is nil and enforcement is enabled
      #
      # @api private
      def self.enforce_schema_presence!(schema, klass, config_flag)
        return schema if schema

        return unless Servus.config.public_send(config_flag)

        raise Servus::Support::Errors::SchemaRequiredError,
              "#{klass.name} schema missing! #{config_flag} is set to true."
      end
    end
  end
end
