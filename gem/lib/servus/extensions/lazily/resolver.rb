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
        # @param optional [Boolean] resolve to +nil+ instead of raising when the value
        #   is nil or finds no record
        # @return [Object, nil] the resolved record or collection, or +nil+ when optional
        # @raise [Errors::NotFoundError] if raw is nil and +optional+ is false
        def self.call(raw, klass:, by:, name:, optional: false)
          return raw if raw.is_a?(klass)

          if raw.nil?
            return nil if optional

            raise Errors::NotFoundError, "Couldn't find #{klass} (#{name} was nil)"
          end

          lookup(raw, klass: klass, by: by, optional: optional)
        end

        # Looks up a present value. +.where+ already omits values that find no
        # record, so arrays resolve the same way whether optional or not.
        #
        # @return [Object, nil]
        def self.lookup(raw, klass:, by:, optional:)
          return klass.where(by => raw) if raw.is_a?(Array)
          return klass.find_by(by => raw) if optional

          by == :id ? klass.find(raw) : klass.find_by!(by => raw)
        end
        private_class_method :lookup
      end
    end
  end
end
