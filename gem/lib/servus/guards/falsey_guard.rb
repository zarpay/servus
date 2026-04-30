# frozen_string_literal: true

module Servus
  module Guards
    # Guard that ensures all specified attributes on an object are falsey.
    #
    # @example Single attribute
    #   enforce_falsey!(on: user, check: :banned)
    #
    # @example Multiple attributes (all must be falsey)
    #   enforce_falsey!(on: post, check: [:deleted, :hidden, :flagged])
    #
    # @example Conditional check
    #   if check_falsey?(on: user, check: :suspended)
    #     # user is not suspended
    #   end
    class FalseyGuard < Servus::Guard
      http_status 422
      error_code 'must_be_falsey'

      message '%<class_name>s.%<failed_attr>s must be falsey (got %<value>s)' do
        message_data
      end

      # Tests whether all specified attributes are falsey.
      #
      # Reads `on` and `check` from the kwargs stored at initialization.
      #
      # @return [Boolean] true if all attributes are falsey
      def test
        Array(check).all? { |attr| !on.public_send(attr) }
      end

      private

      # Builds the interpolation data for the error message.
      #
      # @return [Hash] message interpolation data
      def message_data
        object = kwargs[:on]
        failed = find_failing_attribute(object, Array(kwargs[:check]))
        {
          class_name: object.class.name,
          failed_attr: failed,
          value: object.public_send(failed).inspect
        }
      end

      # Finds the first attribute that fails the falsey check.
      #
      # @param object [Object] the object to check
      # @param checks [Array<Symbol>] attributes to check
      # @return [Symbol] the first failing attribute
      def find_failing_attribute(object, checks)
        checks.find { |attr| !!object.public_send(attr) }
      end
    end
  end
end
