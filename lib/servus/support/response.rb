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

      # Checks if the service execution failed.
      #
      # @return [Boolean] true if the service failed, false if it succeeded
      #
      # @example
      #   result = MyService.call(params)
      #   return render_error(result.error.message) if result.failure?
      def failure?
        !@success
      end

      # Attaches additional data to the response, merging with any existing data.
      #
      # This is useful for enriching failure responses with structured context
      # beyond the error message, e.g. validation details or domain-specific flags.
      # Returns +self+ so it can be chained or used inside a +tap+ block.
      #
      # @param attributes [Hash] key-value pairs to merge into the response data
      # @return [self]
      #
      # @example Adding data to a failure response
      #   failure("Human approval required").tap do |r|
      #     r.with_data(requires_human_approval: true, ai_approved: true)
      #   end
      def with_data(**attributes)
        @data = (@data || {}).merge(attributes)
        self
      end

      # Allows direct access to data keys as methods.
      #
      # When {#data} is a Hash, you can access its keys directly on the response
      # object. Works for both success and failure responses (e.g. after calling
      # {#with_data}).
      #
      # @example
      #   result = MyService.call(user_id: 123)
      #   result.user   # equivalent to result.data[:user]
      #   result.token  # equivalent to result.data[:token]
      def method_missing(method_name, *args, &)
        if @data.is_a?(Hash)
          key = method_name.to_s
          return @data[key.to_sym] if @data.key?(key.to_sym)
          return @data[key] if @data.key?(key)
        end
        super
      end

      # @api private
      def respond_to_missing?(method_name, include_private = false)
        if @data.is_a?(Hash)
          key = method_name.to_s
          return true if @data.key?(key.to_sym) || @data.key?(key)
        end
        super
      end
    end
  end
end
