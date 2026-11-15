# frozen_string_literal: true

module Servus
  module Extensions
    module Lazily
      # Performs the actual record resolution for a lazily-declared input.
      #
      # Handles the decision logic: is the raw value already an instance,
      # absent, an array, or a lookup value? Delegates to the appropriate
      # finder method on the target class.
      #
      # @api private
      class Resolver
        # Resolves a raw value to a record (or collection of records).
        #
        # A value is absent when it is +nil+ or, when dry-initializer is loaded,
        # +Dry::Initializer::UNDEFINED+ (an +option+ that was left out).
        #
        # @param raw [Object] the raw input value (ID, instance, Array, nil or UNDEFINED)
        # @param klass [Class] the target model class
        # @param by [Symbol] the lookup column
        # @param name [Symbol] the param name (for error messages)
        # @param optional [Boolean] resolve to +nil+ instead of raising when the value
        #   is absent or finds no record
        # @return [Object, nil] the resolved record or collection, or +nil+ when optional
        # @raise [Errors::NotFoundError] if raw is absent and +optional+ is false
        def self.call(raw, klass:, by:, name:, optional: false)
          return raw if raw.is_a?(klass)

          if absent?(raw)
            return nil if optional

            raise Errors::NotFoundError, "Couldn't find #{klass} (#{name} was #{raw.nil? ? 'nil' : 'not given'})"
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

        # @param raw [Object]
        # @return [Boolean] whether +raw+ means "no value given"
        def self.absent?(raw)
          return true if raw.nil?

          defined?(Dry::Initializer::UNDEFINED) ? Dry::Initializer::UNDEFINED.equal?(raw) : false
        end
        private_class_method :absent?
      end
    end
  end
end
