# frozen_string_literal: true

module Servus
  module Guards
    # Guard that ensures all specified attributes on an object are truthy.
    #
    # @example Single attribute
    #   enforce_truthy!(on: user, check: :active)
    #
    # @example Multiple attributes (all must be truthy)
    #   enforce_truthy!(on: user, check: [:active, :verified, :confirmed])
    #
    # @example Conditional check
    #   if check_truthy?(on: subscription, check: :valid?)
    #     # subscription is valid
    #   end
    class TruthyGuard < Servus::Guard
      http_status 422
      error_code 'must_be_truthy'

      message '%<class_name>s.%<failed_attr>s must be truthy (got %<value>s)' do
        message_data
      end

      # Tests whether all specified attributes are truthy.
      #
      # Reads `on` and `check` from the kwargs stored at initialization.
      #
      # @return [Boolean] true if all attributes are truthy
      def test
        Array(check).all? { |attr| !!on.public_send(attr) }
      end

      private

      # Builds the interpolation data for the error message.
      #
      # @return [Hash] message interpolation data
      def message_data
        object = kwargs[:on]
        check  = kwargs[:check]
        failed = find_failing_attribute(object, Array(check))

        {
          failed_attr: failed,
          class_name: object.class.name,
          value: object.public_send(failed).inspect
        }
      end

      # Finds the first attribute that fails the truthy check.
      #
      # @param object [Object] the object to check
      # @param checks [Array<Symbol>] attributes to check
      # @return [Symbol] the first failing attribute
      def find_failing_attribute(object, checks)
        checks.find { |attr| !object.public_send(attr) }
      end
    end
  end
end
