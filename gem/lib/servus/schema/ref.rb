# frozen_string_literal: true

module Servus
  module Schema
    # A parsed +$ref+ pointing at a registered schema fragment.
    #
    # Servus supports exactly two ref forms:
    #
    #   #/core                  # the whole fragment registered as "core"
    #   #/core/$defs/amount     # a path walked within it
    #
    # Segments are literal hash keys, not JSON Pointer tokens — there is no
    # +~0+/+~1+ unescaping and no array indexing. +$defs+ carries no special
    # meaning; it is a conventional place to put definitions, and any key works.
    #
    # Everything else is rejected by {parse} with a message that names what was
    # wrong. That matters most for local refs: +#/$defs/amount+ would otherwise
    # parse as a request for a fragment registered under the key +$defs+ and
    # fail as a confusing lookup miss rather than as the unsupported form it is.
    #
    # @see Servus::Schema::Compiler
    class Ref
      # Ref forms Servus does not implement, paired with the reason.
      #
      # Checked in order; the first match raises {InvalidRefError}.
      #
      # @api private
      REJECTIONS = [
        [
          ->(value) { !value.start_with?('#/') },
          'Servus resolves refs against registered schema fragments, which always take the form ' \
          '"#/<key>" or "#/<key>/<path>". Remote and file refs are not supported.'
        ],
        [
          ->(value) { value == '#/' },
          'it names no schema fragment key.'
        ],
        [
          ->(value) { value.delete_prefix('#/').start_with?('$') },
          'it looks like a local ref. Refs resolve against registered fragments, not against the ' \
          'enclosing document. Register the shared definition as a fragment and reference it as ' \
          '"#/<key>/...".'
        ]
      ].freeze

      # The original ref string.
      #
      # @return [String]
      attr_reader :value

      # The registry key the ref names.
      #
      # @return [String]
      attr_reader :key

      # Path segments to walk within the fragment. Empty for a whole-fragment ref.
      #
      # @return [Array<String>]
      attr_reader :segments

      # Parses a +$ref+ value.
      #
      # @param value [Object] the raw +$ref+ value from a schema
      # @return [Ref]
      # @raise [InvalidRefError] if the value is not a supported ref form
      #
      # @example
      #   Servus::Schema::Ref.parse('#/core/$defs/amount').key  # => "core"
      def self.parse(value)
        raise InvalidRefError, "$ref must be a String, got #{value.class}: #{value.inspect}" unless value.is_a?(String)

        _, explanation = REJECTIONS.find { |rejects, _| rejects.call(value) }

        raise InvalidRefError, "#{value.inspect} is not a supported $ref — #{explanation}" if explanation

        new(value)
      end

      # @param value [String] a ref string already known to be well-formed
      # @api private
      def initialize(value)
        @value = value
        @key, *@segments = value.delete_prefix('#/').split('/')
      end

      # @return [String] the ref string
      def to_s = value
    end
  end
end
