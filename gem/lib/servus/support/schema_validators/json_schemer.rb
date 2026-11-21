# frozen_string_literal: true

module Servus
  module Support
    module SchemaValidators
      # Validates with the +json_schemer+ gem, as Draft 6, reading each
      # +pattern+ as ECMAScript so +^...$+ covers the whole value. Everything
      # else is read as {JsonSchema} reads it: Symbols in a schema as strings,
      # and formats checked as +json-schema+ checks them.
      #
      # @api private
      class JsonSchemer
        # Formats +json_schemer+ checks under Draft 6 that +json-schema+ does not.
        UNCHECKED_FORMATS = %w[email hostname uri-reference uri-template json-pointer].freeze

        class << self
          # @param schema [Hash] the JSON schema to validate against
          # @param data [Object] the data, already serialized to JSON types
          # @return [Array<String>] one message per error, empty when the data is valid
          #
          # @example
          #   JsonSchemer.errors({ 'pattern' => '^[0-9]+$' }, "1\nx")
          #   # => ["string at root does not match pattern: ^[0-9]+$"]
          def errors(schema, data)
            compiled(schema).validate(data).map { |error| error['error'] }
          end

          private

          # The schema compiled once per schema Hash. +stringify+ is what
          # +json-schema+ runs on a schema, so +required: %i[name]+ requires the
          # +"name"+ key serialized data carries.
          #
          # @param schema [Hash] the JSON schema to compile
          # @return [JSONSchemer::Schema]
          #
          # @example
          #   compiled({ 'type' => 'string' }).valid?('a') # => true
          def compiled(schema)
            cache[schema] ||= JSONSchemer.schema(
              JSON::Schema.stringify(schema),
              meta_schema: JSONSchemer.draft6,
              regexp_resolver: 'ecma',
              formats: formats
            )
          end

          # @return [Hash{String => false, Method}] each format checked otherwise than +json_schemer+ would
          #
          # @example
          #   formats['email'] # => false
          def formats
            @formats ||= UNCHECKED_FORMATS.to_h { |format| [format, false] }.merge('uri' => method(:uri?))
          end

          # A +uri+ as +json-schema+ takes it: any reference it parses, +/path+
          # included, where +json_schemer+ wants an absolute URI.
          #
          # @param value [Object] the value under the +format+ keyword
          # @param _format [String] the format's name
          # @return [Boolean] true for a reference, or for a value that is not a String
          #
          # @example
          #   uri?('/path', 'uri') # => true
          def uri?(value, _format)
            JSON::Util::URI.parse(value) if value.is_a?(String)
            true
          rescue JSON::Schema::UriError
            false
          end

          # @return [ObjectSpace::WeakMap] compiled schemas, keyed by the schema Hash they compile
          #
          # @example
          #   cache[schema] # => #<JSONSchemer::Schema ...>
          def cache
            @cache ||= ObjectSpace::WeakMap.new
          end
        end
      end
    end
  end
end
