# frozen_string_literal: true

module Servus
  module Support
    # Response class for service results
    class Response
      # [Object] The data returned by the service
      attr_reader :data

      # [Servus::Support::Errors::ServiceError] The error returned by the service
      attr_reader :error

      # Initializes a new response
      #
      # @param success [Boolean] Whether the response was successful
      # @param data [Object] The data returned by the service
      # @param error [Servus::Support::Errors::ServiceError] The error returned by the service
      def initialize(success, data, error)
        @success = success
        @data = data
        @error = error
      end

      # Returns whether the response was successful
      #
      # @return [Boolean] Whether the response was successful
      def success?
        @success
      end
    end
  end
end
