# frozen_string_literal: true

module Servus
  module Guards
    # Guard that ensures an attribute matches an expected value or one of several allowed values.
    #
    # @example Single expected value
    #   enforce_state!(on: order, check: :status, is: :pending)
    #
    # @example Multiple allowed values (any match passes)
    #   enforce_state!(on: account, check: :status, is: [:active, :trial])
    #
    # @example Conditional check
    #   if check_state?(on: order, check: :status, is: :shipped)
    #     # order is shipped
    #   end
    class StateGuard < Servus::Guard
      http_status 422
      error_code 'invalid_state'

      message '%<class_name>s.%<attr>s must be %<expected>s (got %<actual>s)' do
        message_data
      end

      # Tests whether the attribute matches the expected value(s).
      #
      # Reads `on`, `check`, and `is` from the kwargs stored at initialization.
      #
      # @return [Boolean] true if attribute matches expected value(s)
      def test
        Array(kwargs[:is]).include?(on.public_send(check))
      end

      private

      # Builds the interpolation data for the error message.
      #
      # @return [Hash] message interpolation data
      def message_data
        object   = kwargs[:on]
        attr     = kwargs[:check]
        expected = kwargs[:is]

        {
          attr: attr,
          class_name: object.class.name,
          actual: object.public_send(attr),
          expected: format_expected(expected)
        }
      end

      # Formats the expected value(s) for the error message.
      #
      # @param expected [Object, Array] the expected value(s)
      # @return [String] formatted expected value(s)
      def format_expected(expected)
        expected.is_a?(Array) ? "one of #{expected.join(', ')}" : expected.to_s
      end
    end
  end
end
