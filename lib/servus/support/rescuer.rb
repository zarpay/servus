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
        base.class_attribute :rescuable_errors, default: []
        base.class_attribute :rescuable_error_type, default: nil
        base.singleton_class.prepend(CallOverride)
        base.extend(ClassMethods)
      end

      # Class-level methods for configuring error handling.
      module ClassMethods
        # Configures automatic error handling for the service.
        #
        # Declares which exception classes should be automatically rescued and converted
        # to failure responses. When a rescued exception occurs, it's wrapped in the
        # specified ServiceError type with a formatted message including the original
        # exception details.
        #
        # @param errors [Array<Class>] one or more exception classes to rescue
        # @param use [Class] ServiceError subclass to use for failures
        #   (defaults to {Servus::Support::Errors::ServiceError})
        # @return [void]
        #
        # @example Rescuing API errors
        #   class PaymentService < Servus::Base
        #     rescue_from Stripe::APIError,
        #       use: Servus::Support::Errors::ServiceUnavailableError
        #
        #     def call
        #       Stripe::Charge.create(...)
        #     end
        #   end
        #
        # @example Rescuing multiple error types
        #   class DataImportService < Servus::Base
        #     rescue_from CSV::MalformedCSVError, JSON::ParserError,
        #       use: Servus::Support::Errors::BadRequestError
        #   end
        #
        # @see Servus::Support::Errors
        def rescue_from(*errors, use: Servus::Support::Errors::ServiceError)
          self.rescuable_errors = errors
          self.rescuable_error_type = use
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
          if rescuable_errors.any?
            begin
              super
            rescue *rescuable_errors => e
              handle_failure(e, rescuable_error_type)
            end
          else
            super
          end
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
