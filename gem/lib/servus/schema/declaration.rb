# frozen_string_literal: true

module Servus
  module Schema
    # Provides the +schema+ DSL to a class.
    #
    # Extend a class with this and call {#declare_schemas} with the schema
    # kinds it supports. {Servus::Base} declares +arguments+, +result+, and
    # +failure+; {Servus::Event} declares +payload+. Each kind gets:
    #
    # * a keyword on the generated +schema+ class method
    # * a reader returning the *compiled* schema, e.g. +arguments_schema+
    # * a reader returning the schema as authored, e.g. +raw_arguments_schema+
    #
    # == Compiled on read
    #
    # The plain reader compiles, so every consumer — validation, the test
    # example builders, the +have_schema+ matcher, application code reading a
    # service's contract — sees resolved +$ref+s without having to know that
    # compilation exists. Results are memoized per class against
    # {Servus::Schema.generation}, so registering a changed fragment rebuilds
    # dependent schemas with no dependency tracking.
    #
    # == Inheritance
    #
    # Readers walk the ancestor chain, so a subclass of a schema-bearing class
    # inherits its contract. Without this a subclass silently validates nothing,
    # which is the failure mode this whole subsystem is built to prevent.
    #
    # @see Servus::Base.schema
    # @see Servus::Event.schema
    module Declaration
      # Defines the +schema+ DSL and its readers for the given kinds.
      #
      # @param types [Array<Symbol>] the schema kinds this class supports
      # @return [void]
      #
      # @example
      #   class Servus::Event
      #     extend Servus::Schema::Declaration
      #     declare_schemas :payload
      #   end
      def declare_schemas(*types)
        @schema_types = types.freeze

        types.each do |type|
          define_singleton_method(:"#{type}_schema") { compiled_schema(type) }
          define_singleton_method(:"raw_#{type}_schema") { raw_schema(type) }
        end
      end

      # The schema kinds this class supports.
      #
      # @return [Array<Symbol>]
      # @api private
      def schema_types
        @schema_types || superclass.schema_types
      end

      # Declares schemas for this class.
      #
      # Omitting a keyword leaves any previously declared schema of that kind
      # in place. Passing one explicitly as +nil+ raises, rather than quietly
      # leaving the class unvalidated — a lookup that returns nil is a bug at
      # the call site, and swallowing it is how contracts silently disappear.
      #
      # @param schemas [Hash{Symbol => Hash}] schema kind to JSON Schema
      # @return [void]
      # @raise [ArgumentError] on an unknown kind or an explicit nil
      #
      # @example
      #   schema arguments: { type: 'object', required: ['user_id'] }
      def schema(**schemas)
        validate_schema_kinds!(schemas.keys)

        schemas.each do |type, value|
          raise ArgumentError, nil_schema_message(type) if value.nil?

          instance_variable_set(:"@raw_#{type}_schema", value.with_indifferent_access)
        end

        @compiled_schemas = nil
      end

      private

      # @param types [Array<Symbol>]
      # @return [void]
      # @raise [ArgumentError]
      # @api private
      def validate_schema_kinds!(types)
        unknown = types - schema_types
        return if unknown.empty?

        raise ArgumentError,
              "unknown schema #{'kind'.pluralize(unknown.size)} #{unknown.map(&:inspect).join(', ')} " \
              "for #{name}. Valid: #{schema_types.map(&:inspect).join(', ')}."
      end

      # @param type [Symbol]
      # @return [String]
      # @api private
      def nil_schema_message(type)
        "#{name} declared a nil #{type} schema. Pass a Hash, or omit the keyword entirely — " \
          'an explicit nil is usually a lookup that failed, and accepting it would leave this ' \
          'class silently unvalidated.'
      end

      # The schema as authored, from this class or the nearest ancestor.
      #
      # @param type [Symbol]
      # @return [Hash, nil]
      # @api private
      def raw_schema(type)
        klass = self

        while klass.respond_to?(:raw_schema, true)
          declared = klass.instance_variable_get(:"@raw_#{type}_schema")
          return declared if declared

          klass = klass.superclass
        end

        nil
      end

      # The compiled schema, memoized against the registry generation.
      #
      # @param type [Symbol]
      # @return [Hash, nil]
      # @raise [Servus::Schema::Error] if a ref cannot be resolved
      # @api private
      def compiled_schema(type)
        generation = Schema.generation
        @compiled_schemas = nil unless @compiled_generation == generation
        @compiled_generation = generation
        @compiled_schemas ||= {}

        return @compiled_schemas[type] if @compiled_schemas.key?(type)

        compiled = Schema.compile(raw_schema(type), context: "#{name} #{type} schema")

        # Compilation rebuilds hashes as it walks, so the indifferent access
        # applied at declaration does not survive it. Readers are public API;
        # restore it rather than making callers know which keys are strings.
        @compiled_schemas[type] = compiled&.with_indifferent_access
      end
    end
  end
end
