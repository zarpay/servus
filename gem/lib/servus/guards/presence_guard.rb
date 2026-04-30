# frozen_string_literal: true

module Servus
  module Guards
    # Guard that ensures all provided values are present (not nil or empty).
    #
    # This is a flexible guard that accepts any number of keyword arguments
    # and validates that all values are present.
    #
    # @example Basic usage
    #   class MyService < Servus::Base
    #     def call
    #       enforce_presence!(user: user, account: account)
    #       # ...
    #     end
    #   end
    #
    # @example Single value
    #   enforce_presence!(email: email)
    #
    # @example Multiple values
    #   enforce_presence!(user: user, account: account, device: device)
    #
    # @example Conditional check
    #   if check_presence?(user: user)
    #     # user is present
    #   end
    class PresenceGuard < Servus::Guard
      http_status 422
      error_code 'must_be_present'

      message '%<key>s must be present (got %<value>s)' do
        message_data
      end

      # Tests whether all provided values are present.
      #
      # A value is considered present if it is not nil and not empty
      # (for values that respond to empty?). Reads all values from the
      # kwargs stored at initialization.
      #
      # @return [Boolean] true if all values are present
      def test
        kwargs.all? { |_, value| present?(value) }
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

      # Finds the first key-value pair that fails the presence check.
      #
      # @return [Array<Symbol, Object>] the failing key and value
      def find_failing_entry
        kwargs.find { |_, value| !present?(value) }
      end

      # Checks if a value is present (not nil and not empty).
      #
      # @param value [Object] the value to check
      # @return [Boolean] true if present
      def present?(value)
        return false if value.nil?
        return !value.empty? if value.respond_to?(:empty?)

        true
      end
    end
  end
end
