# frozen_string_literal: true

module Servus
  module Support
    module Errors
      # Base error class for application services
      #
      # @param message [String] The error message
      # @return [ServiceError] The error instance
      class ServiceError < StandardError
        attr_reader :message

        DEFAULT_MESSAGE = 'An error occurred'

        # Initializes a new error instance
        # @param message [String] The error message
        # @return [ServiceError] The error instance
        def initialize(message = nil)
          @message = message || self.class::DEFAULT_MESSAGE
          super("#{self.class}: #{message}")
        end

        # 404 error response
        # @return [Hash] The error response
        def api_error
          { code: :bad_request, message: message }
        end
      end

      # Error class for bad request errors
      # @param message [String] The error message
      # @return [BadRequestError] The error instance
      class BadRequestError < ServiceError
        DEFAULT_MESSAGE = 'Bad request'

        # 400 error response
        # @return [Hash] The error response
        def api_error
          { code: :bad_request, message: message }
        end
      end

      # Error class for authentication errors
      # @param message [String] The error message
      # @return [AuthenticationError] The error instance
      class AuthenticationError < ServiceError
        DEFAULT_MESSAGE = 'Authentication failed'

        # 401 error response
        # @return [Hash] The error response
        def api_error
          { code: :unauthorized, message: message }
        end
      end

      # Error class for unauthorized errors
      # @param message [String] The error message
      # @return [UnauthorizedError] The error instance
      class UnauthorizedError < AuthenticationError
        DEFAULT_MESSAGE = 'Unauthorized'
      end

      # Error class for forbidden errors
      # @param message [String] The error message
      # @return [ForbiddenError] The error instance
      class ForbiddenError < ServiceError
        DEFAULT_MESSAGE = 'Forbidden'

        # 403 error response
        # @return [Hash] The error response
        def api_error
          { code: :forbidden, message: message }
        end
      end

      # Error class for not found errors
      # @param message [String] The error message
      # @return [NotFoundError] The error instance
      class NotFoundError < ServiceError
        DEFAULT_MESSAGE = 'Not found'

        # 404 error response
        # @return [Hash] The error response
        def api_error
          { code: :not_found, message: message }
        end
      end

      # Error class for unprocessable entity errors
      # @param message [String] The error message
      # @return [UnprocessableEntityError] The error instance
      class UnprocessableEntityError < ServiceError
        DEFAULT_MESSAGE = 'Unprocessable entity'

        # 422 error response
        # @return [Hash] The error response
        def api_error
          { code: :unprocessable_entity, message: message }
        end
      end

      # Error class for validation errors
      # @param message [String] The error message
      # @return [ValidationError] The error instance
      class ValidationError < UnprocessableEntityError
        DEFAULT_MESSAGE = 'Validation failed'
      end

      # Error class for internal server errors
      # @param message [String] The error message
      # @return [InternalServerError] The error instance
      class InternalServerError < ServiceError
        DEFAULT_MESSAGE = 'Internal server error'

        # 500 error response
        # @return [Hash] The error response
        def api_error
          { code: :internal_server_error, message: message }
        end
      end

      # Error class for service unavailable errors
      # @param message [String] The error message
      # @return [ServiceUnavailableError] The error instance
      class ServiceUnavailableError < ServiceError
        DEFAULT_MESSAGE = 'Service unavailable'

        # 503 error response
        # @return [Hash] The error response
        def api_error
          { code: :service_unavailable, message: message }
        end
      end
    end
  end
end
