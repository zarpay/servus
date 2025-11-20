# frozen_string_literal: true

module Servus
  module Testing
    # Extracts example values from JSON Schema definitions for use in testing.
    #
    # This class understands both OpenAPI-style `example` (singular) and
    # JSON Schema-style `examples` (plural, array) keywords. It can handle
    # nested objects, arrays, and complex schema structures.
    #
    # @example Basic extraction
    #   schema = {
    #     type: 'object',
    #     properties: {
    #       name: { type: 'string', example: 'John Doe' },
    #       age: { type: 'integer', example: 30 }
    #     }
    #   }
    #
    #   extractor = ExampleExtractor.new(schema)
    #   extractor.extract
    #   # => { name: 'John Doe', age: 30 }
    #
    # @example With service class
    #   examples = ExampleExtractor.extract(MyService, :arguments)
    #   # => { user_id: 123, amount: 100.0 }
    #
    # @see https://json-schema.org/understanding-json-schema/reference/annotations
    # @see https://spec.openapis.org/oas/v3.1.0#schema-object
    class ExampleExtractor
      # Extracts example values from a service class's schema.
      #
      # This is a convenience class method that loads the schema via the
      # Validator and extracts examples in one call.
      #
      # @param service_class [Class] The service class to extract examples from
      # @param schema_type [Symbol] Either :arguments or :result
      # @return [Hash<Symbol, Object>] Extracted example values with symbolized keys
      #
      # @example Extract argument examples
      #   ExampleExtractor.extract(ProcessPayment::Service, :arguments)
      #   # => { user_id: 123, amount: 100.0, currency: 'USD' }
      #
      # @example Extract result examples
      #   ExampleExtractor.extract(ProcessPayment::Service, :result)
      #   # => { transaction_id: 'txn_123', status: 'approved' }
      def self.extract(service_class, schema_type)
        schema = load_schema(service_class, schema_type)
        return {} unless schema

        new(schema).extract
      end

      # Initializes a new ExampleExtractor with a schema.
      #
      # The schema is deeply symbolized on initialization to normalize all keys,
      # eliminating the need for double lookups throughout extraction.
      #
      # @param schema [Hash, nil] A JSON Schema hash with properties and examples
      #
      # @example
      #   schema = { type: 'object', properties: { name: { example: 'Test' } } }
      #   extractor = ExampleExtractor.new(schema)
      def initialize(schema)
        @schema = deep_symbolize_keys(schema)
      end

      # Extracts all example values from the schema.
      #
      # Traverses the schema structure and collects example values from:
      # - Simple properties with `example` or `examples` keywords
      # - Nested objects (recursively)
      # - Arrays (using array-level examples or generating from item schemas)
      #
      # @return [Hash<Symbol, Object>] Hash of example values with symbolized keys
      #
      # @example Simple properties
      #   schema = {
      #     type: 'object',
      #     properties: {
      #       name: { type: 'string', example: 'John' },
      #       age: { type: 'integer', examples: [30, 25, 40] }
      #     }
      #   }
      #   extractor = ExampleExtractor.new(schema)
      #   extractor.extract
      #   # => { name: 'John', age: 30 }
      #
      # @example Nested objects
      #   schema = {
      #     type: 'object',
      #     properties: {
      #       user: {
      #         type: 'object',
      #         properties: {
      #           id: { type: 'integer', example: 123 },
      #           name: { type: 'string', example: 'Jane' }
      #         }
      #       }
      #     }
      #   }
      #   extractor = ExampleExtractor.new(schema)
      #   extractor.extract
      #   # => { user: { id: 123, name: 'Jane' } }
      def extract
        return {} unless @schema.is_a?(Hash)

        extract_examples_from_properties(@schema)
      end

      private

      # Extracts examples from schema properties.
      #
      # Iterates through the properties hash and extracts example values
      # for each property that has one defined.
      #
      # @param schema [Hash] Schema hash containing a :properties key
      # @return [Hash<Symbol, Object>] Extracted examples with symbolized keys
      #
      # @api private
      def extract_examples_from_properties(schema)
        properties = schema[:properties]
        return {} unless properties

        properties.each_with_object({}) do |(key, property_schema), examples|
          example_value = extract_example_value(property_schema)
          examples[key.to_sym] = example_value unless example_value.nil? && !explicit_nil_example?(property_schema)
        end
      end

      # Extracts a single example value from a property schema.
      #
      # Handles different types of properties:
      # - Simple types with `example` or `examples` keywords
      # - Nested objects (recursively extracts)
      # - Arrays (uses array example or generates from items)
      #
      # @param property_schema [Hash] The schema for a single property
      # @return [Object, nil] The example value, or nil if none found
      #
      # @api private
      def extract_example_value(property_schema)
        return nil unless property_schema.is_a?(Hash)

        # Check for direct example keywords first
        return get_example_from_keyword(property_schema) if example_keyword?(property_schema)

        # Handle nested objects
        return extract_examples_from_properties(property_schema) if nested_object?(property_schema)

        # Handle arrays
        return extract_array_example(property_schema) if array_type?(property_schema)

        nil
      end

      # Checks if property has an example keyword (example or examples).
      #
      # @param property_schema [Hash] Property schema to check
      # @return [Boolean] True if example or examples keyword exists
      #
      # @api private
      def example_keyword?(property_schema)
        property_schema.key?(:example) || property_schema.key?(:examples)
      end

      # Checks if property explicitly sets example to nil.
      #
      # This is important to distinguish between "no example" and "example is nil".
      #
      # @param property_schema [Hash] Property schema to check
      # @return [Boolean] True if example is explicitly set to nil
      #
      # @api private
      def explicit_nil_example?(property_schema)
        property_schema.key?(:example) && property_schema[:example].nil?
      end

      # Gets the example value from the example/examples keyword.
      #
      # Handles both:
      # - `:example` (singular): returns the value directly
      # - `:examples` (plural): returns a value from the array
      #
      # @param property_schema [Hash] Property schema with example keyword
      # @return [Object] The example value
      #
      # @api private
      def get_example_from_keyword(property_schema)
        # Check for :example (singular) first - OpenAPI style
        return property_schema[:example] if property_schema.key?(:example)

        # Check for :examples (plural) - JSON Schema style
        examples = property_schema[:examples]
        return nil unless examples.is_a?(Array) && examples.any?

        examples.sample
      end

      # Checks if property is a nested object type.
      #
      # @param property_schema [Hash] Property schema to check
      # @return [Boolean] True if type is object and has properties
      #
      # @api private
      def nested_object?(property_schema)
        property_schema[:type] == 'object' && property_schema[:properties]
      end

      # Checks if property is an array type.
      #
      # @param property_schema [Hash] Property schema to check
      # @return [Boolean] True if type is array
      #
      # @api private
      def array_type?(property_schema)
        property_schema[:type] == 'array'
      end

      # Extracts example value for an array property.
      #
      # Handles two strategies:
      # 1. If array has direct `example` keyword, use it
      # 2. Otherwise, generate array with one item using item schema examples
      #
      # @param property_schema [Hash] Array property schema
      # @return [Array, nil] Array example or nil if can't be generated
      #
      # @example Array with direct example
      #   { type: 'array', example: [1, 2, 3] }
      #   # => [1, 2, 3]
      #
      # @example Array with item schema examples
      #   {
      #     type: 'array',
      #     items: {
      #       type: 'object',
      #       properties: {
      #         id: { type: 'integer', examples: [1, 2] },
      #         name: { type: 'string', examples: ['John', 'Jane'] }
      #       }
      #     }
      #   }
      #   # => [{ id: 1, name: 'John' }]
      #
      # @api private
      def extract_array_example(property_schema)
        # If array has direct example, use it
        return get_example_from_keyword(property_schema) if example_keyword?(property_schema)

        # Otherwise, try to generate an array with one item from the items schema
        items_schema = property_schema[:items]
        return nil unless items_schema

        # Generate one example item from the items schema
        if nested_object?(items_schema)
          item_example = extract_examples_from_properties(items_schema)
          return [item_example] if item_example.any?
        elsif example_keyword?(items_schema)
          return [get_example_from_keyword(items_schema)]
        end

        nil
      end

      # Recursively converts all hash keys to symbols.
      #
      # Handles nested hashes and arrays of hashes, ensuring consistent
      # key types throughout the structure.
      #
      # @param value [Object] The value to process
      # @return [Object] The value with all hash keys symbolized
      #
      # @api private
      def deep_symbolize_keys(value)
        case value
        when Hash
          value.each_with_object({}) do |(key, val), result|
            result[key.to_sym] = deep_symbolize_keys(val)
          end
        when Array
          value.map { |item| deep_symbolize_keys(item) }
        else
          value
        end
      end

      # Loads schema from service class using Validator.
      #
      # Reuses the existing Validator schema loading logic which handles:
      # - DSL-defined schemas
      # - Constant-defined schemas
      # - File-based schemas
      # - Schema caching
      #
      # @param service_class [Class] The service class
      # @param schema_type [Symbol] Either :arguments or :result
      # @return [Hash, nil] The loaded schema or nil
      #
      # @api private
      def self.load_schema(service_class, schema_type)
        Servus::Support::Validator.load_schema(service_class, schema_type.to_s)
      end

      private_class_method :load_schema
    end
  end
end
