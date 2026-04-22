# frozen_string_literal: true

module Servus
  module Guards
    # Guard that ensures an ActiveModel-compatible record has been persisted.
    #
    # Useful after `Model.create(...)` or `record.save` where validation
    # failure leaves the record un-persisted with `errors` populated. Surfaces
    # the record's full error messages as the failure message.
    #
    # @example Basic usage
    #   class CreateUser < Servus::Base
    #     def call
    #       user = User.create(email: email, name: name)
    #       enforce_persisted!(record: user)
    #       success(user: user)
    #     end
    #   end
    #
    # @example Conditional check
    #   if check_persisted?(record: user)
    #     # user is persisted
    #   end
    class PersistedGuard < Servus::Guard
      http_status 422
      error_code 'record_not_persisted'

      message '%<errors>s' do
        message_data
      end

      # Tests whether the record has been persisted.
      #
      # @param record [#persisted?, #errors] an ActiveModel-compatible record
      # @return [Boolean] true if the record is persisted
      def test(record:)
        record.persisted?
      end

      private

      # Builds the interpolation data for the error message.
      #
      # @return [Hash] message interpolation data
      def message_data
        { errors: kwargs[:record].errors.full_messages.to_sentence }
      end
    end
  end
end
