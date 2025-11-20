# frozen_string_literal: true

module Servus
  module Support
    # Provides automatic error handling for services via {ClassMethods#rescue_from}.
    #
    # This module enables services to declare which exceptions should be automatically
    # caught and converted to failure responses, eliminating repetitive rescue blocks.
    #
    # @example Basic usage
    #   class MyService < Servus::Base
    #     rescue_from Net::HTTPError, Timeout::Error,
    #       use: Servus::Support::Errors::ServiceUnavailableError
    #
    #     def call
    #       make_external_api_call  # May raise Net::HTTPError
    #     end
    #   end
    #
    # @see ClassMethods#rescue_from
    module Rescuer
      # Sets up error rescue functionality when included.
      #
      # @param base [Class] the class including this module (typically {Servus::Base})
      # @api private
      def self.included(base)
        base.class_attribute :rescuable_configs, default: []
        base.singleton_class.prepend(CallOverride)
        base.extend(ClassMethods)
      end

      # Provides success/failure methods to rescue_from blocks.
      #
      # This context is used when a rescue_from block is executed. It provides
      # the same success() and failure() methods available in service call methods,
      # allowing blocks to create appropriate Response objects.
      #
      # @api private
      class BlockContext
        def initialize
          @result = nil
        end

        # Creates a success response.
        #
        # Use this in rescue_from blocks to recover from exceptions and return
        # successful results despite the error being raised.
        #
        # @param data [Hash, Object] The success data to return
        # @return [Servus::Support::Response] Success response
        #
        # @example
        #   rescue_from SomeError do |exception|
        #     success(recovered: true, original_error: exception.message)
        #   end
        def success(data = nil)
          @result = Response.new(true, data, nil)
        end

        # Creates a failure response.
        #
        # Use this in rescue_from blocks to convert exceptions into business failures
        # with custom messages and error types.
        #
        # @param message [String, nil] The error message (uses error type's DEFAULT_MESSAGE if nil)
        # @param type [Class<Servus::Support::Errors::ServiceError>] The error type
        # @return [Servus::Support::Response] Failure response
        #
        # @example
        #   rescue_from ActiveRecord::RecordInvalid do |exception|
        #     failure("Database error: #{exception.message}", type: InternalServerError)
        #   end
        def failure(message = nil, type: Servus::Support::Errors::ServiceError)
          error = type.new(message)
          @result = Response.new(false, nil, error)
        end

        # The response created by success() or failure().
        #
        # @return [Servus::Support::Response, nil] The response, or nil if neither method was called
        # @api private
        attr_reader :result
      end

      # Class methods for rescue_from
      module ClassMethods
        # Configures automatic error handling for the service.
        #
        # Declares which exception classes should be automatically rescued and converted
        # to failure responses. Without a block, exceptions are wrapped in the specified
        # ServiceError type with a formatted message including the original exception details.
        #
        # When a block is provided, it receives the exception and must return either
        # `success(data)` or `failure(message, type:)` to create the response.
        #
        # @example Basic usage with default error type:
        #   class TestService < Servus::Base
        #     rescue_from Net::HTTPError, Timeout::Error, use: ServiceUnavailableError
        #   end
        #
        # @example Custom error handling with block:
        #   class TestService < Servus::Base
        #     rescue_from ActiveRecord::RecordInvalid do |exception|
        #       failure("Validation failed: #{exception.message}", type: ValidationError)
        #     end
        #   end
        #
        # @example Recovering from errors with success:
        #   class TestService < Servus::Base
        #     rescue_from Stripe::CardError do |exception|
        #       if exception.code == 'card_declined'
        #         failure("Card declined", type: BadRequestError)
        #       else
        #         success(recovered: true, fallback_used: true)
        #       end
        #     end
        #   end
        #
        # @param errors [Class<StandardError>] One or more exception classes to rescue from
        # @param use [Class<Servus::Support::Errors::ServiceError>] Error class to use when wrapping exceptions (only used without block)
        # @yield [exception] Optional block for custom error handling
        # @yieldparam exception [StandardError] The caught exception
        # @yieldreturn [Servus::Support::Response] Must return success() or failure() response
        def rescue_from(*errors, use: Servus::Support::Errors::ServiceError, &block)
          config = {
            errors: errors,
            error_type: use,
            handler: block
          }

          # Add to rescuable_configs array
          self.rescuable_configs = rescuable_configs + [config]
        end
      end

      # Wraps the service's .call method with error handling logic.
      #
      # This module is prepended to the service's singleton class, allowing it to
      # intercept calls and add rescue behavior before delegating to the original implementation.
      #
      # @api private
      module CallOverride
        # Wraps the service call with automatic error rescue.
        #
        # If rescuable_errors are configured, wraps the call in a rescue block.
        # Caught exceptions are converted to failure responses using {#handle_failure}.
        #
        # @param args [Hash] keyword arguments passed to the service
        # @return [Servus::Support::Response] the service result or failure response
        #
        # @api private
        def call(**args)
          return super if rescuable_configs.empty?

          begin
            super
          rescue StandardError => e
            handle_rescued_error(e) || raise
          end
        end

        private

        # Handle a rescued error by finding matching config and processing it
        #
        # @param error [StandardError] The error to handle
        # @return [Servus::Support::Response, nil] Response if error was handled, nil otherwise
        def handle_rescued_error(error)
          # Find the first matching config
          config = rescuable_configs.find do |cfg|
            cfg[:errors].any? { |error_class| error.is_a?(error_class) }
          end

          return nil unless config

          if config[:handler]
            # Use the block handler with BlockContext
            block_context_result(error, config)
          else
            # Use the default handling
            handle_failure(error, config[:error_type])
          end
        end

        # Instantiates a block context to handle a rescued error
        #
        # @param error [StandardError] the caught exception
        # @param config [Hash] The rescue config for the current error
        #
        # @api private
        def block_context_result(error, config)
          context = BlockContext.new
          context.instance_exec(error, &config[:handler])
          context.result
        end

        # Creates a failure response from a rescued exception.
        #
        # Converts the caught exception into a ServiceError of the specified type,
        # preserving the original exception information in the error message.
        #
        # @param error [StandardError] the caught exception
        # @param type [Class] ServiceError subclass to wrap the exception in
        # @return [Servus::Support::Response] failure response with the wrapped error
        #
        # @api private
        def handle_failure(error, type)
          error = type.new(template_error_message(error))
          Response.new(false, nil, error)
        end

        # Formats the exception message for the ServiceError.
        #
        # Creates a message that includes both the exception class and its original message,
        # providing context about what actually failed.
        #
        # @param error [StandardError] the caught exception
        # @return [String] formatted error message in the format "[ExceptionClass]: message"
        #
        # @example
        #   template_error_message(Net::HTTPError.new("Connection timeout"))
        #   # => "[Net::HTTPError]: Connection timeout"
        #
        # @api private
        def template_error_message(error)
          "[#{error.class}]: #{error.message}"
        end
      end
    end
  end
end
