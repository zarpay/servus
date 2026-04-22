# frozen_string_literal: true

module Servus
  module Guards
    # Guard that ensures all provided numeric values are strictly positive.
    #
    # Fails for zero, negative, and non-numeric values. Mirrors the shape of
    # {PresenceGuard} — accepts any number of keyword arguments and surfaces
    # the first failing pair in the error message.
    #
    # @example Basic usage
    #   class DebitAccount < Servus::Base
    #     def call
    #       enforce_positivity!(amount: amount, fee: fee)
    #       # ...
    #     end
    #   end
    #
    # @example Single value
    #   enforce_positivity!(amount: 10)
    #
    # @example Conditional check
    #   if check_positivity?(amount: amount)
    #     # amount is positive
    #   end
    class PositivityGuard < Servus::Guard
      http_status 422
      error_code 'must_be_positive'

      message '%<key>s must be positive (got %<value>s)' do
        message_data
      end

      # Tests whether all provided values are strictly positive numerics.
      #
      # @param values [Hash] keyword arguments to validate
      # @return [Boolean] true if all values are strictly positive numerics
      def test(**values)
        values.all? { |_, value| positive?(value) }
      end

      private

      # Builds the interpolation data for the error message.
      #
      # @return [Hash] message interpolation data
      def message_data
        failed_key, failed_value = find_failing_entry

        {
          key: failed_key,
          value: failed_value.inspect
        }
      end

      # Finds the first key-value pair that fails the positivity check.
      #
      # @return [Array<Symbol, Object>] the failing key and value
      def find_failing_entry
        kwargs.find { |_, value| !positive?(value) }
      end

      # Checks if a value is a strictly positive numeric.
      #
      # @param value [Object] the value to check
      # @return [Boolean] true if the value is a numeric greater than zero
      def positive?(value)
        value.is_a?(Numeric) && value.positive?
      end
    end
  end
end
