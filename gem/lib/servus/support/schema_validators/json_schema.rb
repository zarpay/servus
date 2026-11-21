# frozen_string_literal: true

module Servus
  module Support
    module SchemaValidators
      # Validates with the +json-schema+ gem, as Draft 6. A +pattern+ is read
      # as a Ruby regex, so its +^+ and +$+ match at any line.
      #
      # @api private
      class JsonSchema
        # @param schema [Hash] the JSON schema to validate against
        # @param data [Object] the data, already serialized to JSON types
        # @return [Array<String>] one message per error, empty when the data is valid
        #
        # @example
        #   JsonSchema.errors({ 'type' => 'string' }, 1)
        #   # => ["The property '#/' of type integer did not match the following type: string"]
        def self.errors(schema, data)
          JSON::Validator.fully_validate(schema, data)
        end
      end
    end
  end
end
