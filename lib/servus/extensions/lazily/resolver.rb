# frozen_string_literal: true

module Servus
  module Extensions
    module Lazily
      # Performs the actual record resolution for a lazily-declared input.
      #
      # Handles the decision logic: is the raw value already an instance,
      # nil, an array, or a lookup value? Delegates to the appropriate
      # finder method on the target class.
      #
      # @api private
      class Resolver
        # Resolves a raw value to a record (or collection of records).
        #
        # @param raw [Object] the raw input value (ID, instance, Array, or nil)
        # @param klass [Class] the target model class
        # @param by [Symbol] the lookup column
        # @param name [Symbol] the param name (for error messages)
        # @return [Object] the resolved record or collection
        # @raise [Errors::NotFoundError] if raw is nil
        def self.call(raw, klass:, by:, name:)
          return raw if raw.is_a?(klass)
          raise Errors::NotFoundError, "Couldn't find #{klass} (#{name} was nil)" if raw.nil?
          return klass.where(by => raw) if raw.is_a?(Array)

          by == :id ? klass.find(raw) : klass.find_by!(by => raw)
        end
      end
    end
  end
end
