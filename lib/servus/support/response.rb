# frozen_string_literal: true

module Servus
  module Support
    # Encapsulates the result of a service execution.
    #
    # Response objects are returned by all service calls and contain either
    # successful data or an error, never both. Use {#success?} to determine
    # which path to take when handling results.
    #
    # @example Handling a successful response
    #   result = MyService.call(user_id: 123)
    #   if result.success?
    #     puts "Data: #{result.data}"
    #     puts "Error: #{result.error}" # => nil
    #   end
    #
    # @example Handling a failed response
    #   result = MyService.call(user_id: -1)
    #   unless result.success?
    #     puts "Error: #{result.error.message}"
    #     puts "Data: #{result.data}" # => nil
    #   end
    #
    # @example Pattern matching in controllers
    #   result = MyService.call(params)
    #   if result.success?
    #     render json: result.data, status: :ok
    #   else
    #     render json: result.error.message, status: :unprocessable_entity
    #   end
    #
    # @see Servus::Base#success
    # @see Servus::Base#failure
    class Response
      # [Object] The data returned by the service
      attr_reader :data

      # [Servus::Support::Errors::ServiceError] The error returned by the service
      attr_reader :error

      # Creates a new response object.
      #
      # @note This is typically called by {Servus::Base#success} or {Servus::Base#failure}
      #   rather than being instantiated directly.
      #
      # @param success [Boolean] true for successful responses, false for failures
      # @param data [Object, nil] the result data (nil for failures)
      # @param error [Servus::Support::Errors::ServiceError, nil] the error (nil for successes)
      #
      # @api private
      def initialize(success, data, error)
        @success = success
        @data = data
        @error = error
      end

      # Checks if the service execution was successful.
      #
      # @return [Boolean] true if the service succeeded, false if it failed
      #
      # @example
      #   result = MyService.call(params)
      #   if result.success?
      #     # Handle success - result.data is available
      #   else
      #     # Handle failure - result.error is available
      #   end
      def success?
        @success
      end
    end
  end
end
