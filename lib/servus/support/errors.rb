# frozen_string_literal: true

module Servus
  module Support
    # Contains all error classes used by Servus services.
    #
    # All error classes inherit from {ServiceError} and provide both a human-readable
    # message and an API-friendly error response via {ServiceError#api_error}.
    #
    # @see ServiceError
    module Errors
      # Base error class for all Servus service errors.
      #
      # This class provides the foundation for all service-related errors, including:
      # - Default error messages via DEFAULT_MESSAGE constant
      # - API-friendly error responses via {#api_error}
      # - Automatic message fallback to default if none provided
      #
      # @example Creating a custom error type
      #   class MyCustomError < Servus::Support::Errors::ServiceError
      #     DEFAULT_MESSAGE = 'Something went wrong'
      #
      #     def api_error
      #       { code: :custom_error, message: message }
      #     end
      #   end
      #
      # @example Using with failure method
      #   def call
      #     return failure("User not found", type: Servus::Support::Errors::NotFoundError)
      #     # ...
      #   end
      class ServiceError < StandardError
        attr_reader :message

        DEFAULT_MESSAGE = 'An error occurred'

        # Creates a new service error instance.
        #
        # @param message [String, nil] custom error message (uses DEFAULT_MESSAGE if nil)
        # @return [ServiceError] the error instance
        #
        # @example With custom message
        #   error = ServiceError.new("Something went wrong")
        #   error.message # => "Something went wrong"
        #
        # @example With default message
        #   error = ServiceError.new
        #   error.message # => "An error occurred"
        def initialize(message = nil)
          @message = message || self.class::DEFAULT_MESSAGE
          super("#{self.class}: #{message}")
        end

        # Returns an API-friendly error response.
        #
        # This method formats the error for API responses, providing both a
        # symbolic code and the error message. Override in subclasses to customize
        # the error code for specific HTTP status codes.
        #
        # @return [Hash] hash with :code and :message keys
        #
        # @example
        #   error = ServiceError.new("Failed to process")
        #   error.api_error # => { code: :bad_request, message: "Failed to process" }
        def api_error
          { code: :bad_request, message: message }
        end
      end

      # Represents a 400 Bad Request error.
      #
      # Use this error when the client sends malformed or invalid request data.
      #
      # @example
      #   def call
      #     return failure("Invalid JSON format", type: BadRequestError)
      #   end
      class BadRequestError < ServiceError
        DEFAULT_MESSAGE = 'Bad request'

        # 400 error response
        # @return [Hash] The error response
        def api_error
          { code: :bad_request, message: message }
        end
      end

      # Represents a 401 Unauthorized error for authentication failures.
      #
      # Use this error when authentication credentials are missing, invalid, or expired.
      #
      # @example
      #   def call
      #     return failure("Invalid API key", type: AuthenticationError) unless valid_api_key?
      #   end
      class AuthenticationError < ServiceError
        DEFAULT_MESSAGE = 'Authentication failed'

        # @return [Hash] API error response with :unauthorized code
        def api_error
          { code: :unauthorized, message: message }
        end
      end

      # Represents a 401 Unauthorized error (alias for AuthenticationError).
      #
      # Use this error for authorization failures when credentials are valid but
      # lack sufficient permissions.
      #
      # @example
      #   def call
      #     return failure("Access denied", type: UnauthorizedError) unless user.admin?
      #   end
      class UnauthorizedError < AuthenticationError
        DEFAULT_MESSAGE = 'Unauthorized'
      end

      # Represents a 403 Forbidden error.
      #
      # Use this error when the user is authenticated but not authorized to perform
      # the requested action.
      #
      # @example
      #   def call
      #     return failure("Insufficient permissions", type: ForbiddenError) unless can_access?
      #   end
      class ForbiddenError < ServiceError
        DEFAULT_MESSAGE = 'Forbidden'

        # 403 error response
        # @return [Hash] The error response
        def api_error
          { code: :forbidden, message: message }
        end
      end

      # Represents a 404 Not Found error.
      #
      # Use this error when a requested resource cannot be found.
      #
      # @example
      #   def call
      #     user = User.find_by(id: @user_id)
      #     return failure("User not found", type: NotFoundError) unless user
      #   end
      class NotFoundError < ServiceError
        DEFAULT_MESSAGE = 'Not found'

        # @return [Hash] API error response with :not_found code
        def api_error
          { code: :not_found, message: message }
        end
      end

      # Represents a 422 Unprocessable Entity error.
      #
      # Use this error when the request is well-formed but contains semantic errors
      # that prevent processing (e.g., business logic violations).
      #
      # @example
      #   def call
      #     return failure("Order already shipped", type: UnprocessableEntityError) if @order.shipped?
      #   end
      class UnprocessableEntityError < ServiceError
        DEFAULT_MESSAGE = 'Unprocessable entity'

        # @return [Hash] API error response with :unprocessable_entity code
        def api_error
          { code: :unprocessable_entity, message: message }
        end
      end

      # Represents validation failures (inherits 422 status).
      #
      # Automatically raised by the framework when schema validation fails.
      # Can also be used for custom validation errors.
      #
      # @example
      #   def call
      #     return failure("Email format invalid", type: ValidationError) unless valid_email?
      #   end
      class ValidationError < UnprocessableEntityError
        DEFAULT_MESSAGE = 'Validation failed'
      end

      # Represents a 500 Internal Server Error.
      #
      # Use this error for unexpected server-side failures.
      #
      # @example
      #   def call
      #     return failure("Database connection lost", type: InternalServerError) if db_down?
      #   end
      class InternalServerError < ServiceError
        DEFAULT_MESSAGE = 'Internal server error'

        # @return [Hash] API error response with :internal_server_error code
        def api_error
          { code: :internal_server_error, message: message }
        end
      end

      # Represents a 503 Service Unavailable error.
      #
      # Use this error when a service dependency is temporarily unavailable.
      #
      # @example Using with rescue_from
      #   class MyService < Servus::Base
      #     rescue_from Net::HTTPError, use: ServiceUnavailableError
      #
      #     def call
      #       make_external_api_call
      #     end
      #   end
      class ServiceUnavailableError < ServiceError
        DEFAULT_MESSAGE = 'Service unavailable'

        # @return [Hash] API error response with :service_unavailable code
        def api_error
          { code: :service_unavailable, message: message }
        end
      end
    end
  end
end
