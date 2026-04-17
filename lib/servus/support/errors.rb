# frozen_string_literal: true

module Servus
  module Support
    # Contains all error classes used by Servus services.
    #
    # All error classes inherit from {ServiceError} and provide:
    # - {ServiceError#http_status} for the HTTP response status
    # - {ServiceError#api_error} for the JSON response body
    #
    # @see ServiceError
    module Errors
      # Base error class for all Servus service errors.
      #
      # Subclasses define their HTTP status via {#http_status}. The API response
      # format is derived automatically — {#api_error} builds a hash from
      # {#http_status}, {#message}, and the optional {#detail} field. Subclasses
      # should NOT override {#api_error}.
      #
      # The +:code+ in the API response always matches {#http_status}, ensuring
      # the HTTP status and JSON body cannot drift apart. Use {#detail} when
      # consumers need a machine-readable identifier to branch on (e.g.,
      # +'insufficient_funds'+, +'account_frozen'+).
      #
      # @example Creating a custom error type
      #   class InsufficientFundsError < Servus::Support::Errors::UnprocessableEntityError
      #     DEFAULT_MESSAGE = 'Insufficient funds'
      #   end
      #
      # @example Using with failure method
      #   def call
      #     return failure("User not found", type: NotFoundError)
      #   end
      #
      # @example Error with detail for programmatic branching
      #   error = ServiceError.new("Card declined", detail: "card_declined")
      #   error.api_error
      #   # => { code: :bad_request, message: "Card declined", detail: "card_declined" }
      class ServiceError < StandardError
        attr_reader :message

        # @return [String, nil] optional machine-readable error identifier for consumer branching
        attr_reader :detail

        DEFAULT_MESSAGE = 'An error occurred'

        # Creates a new service error instance.
        #
        # @param message [String, nil] custom error message (uses DEFAULT_MESSAGE if nil)
        # @param detail [String, nil] optional machine-readable identifier for programmatic branching
        def initialize(message = nil, detail: nil)
          @message = message || self.class::DEFAULT_MESSAGE
          @detail = detail
          super("#{self.class}: #{@message}")
        end

        # Returns the HTTP status code for this error.
        #
        # @return [Symbol] Rails-compatible status symbol
        def http_status = :bad_request

        # Returns an API-friendly error response.
        #
        # The +:code+ is always derived from {#http_status}, ensuring the HTTP
        # response status and JSON body stay in sync. When {#detail} is set, it
        # is included for consumers that need to branch on a specific error case.
        #
        # @return [Hash] hash with :code, :message, and optionally :detail keys
        def api_error
          hash = { code: http_status, message: message }
          hash[:detail] = detail if detail
          hash
        end
      end

      # Guard validation failure with detail identifier.
      #
      # Guards define their own detail and HTTP status via the DSL. The +:code+
      # in the API response is always the HTTP status symbol; use +:detail+ for
      # machine-readable identifiers consumers can branch on.
      #
      # @example
      #   GuardError.new("Amount must be positive", detail: 'invalid_amount', http_status: :unprocessable_entity)
      class GuardError < ServiceError
        DEFAULT_MESSAGE = 'Guard validation failed'

        # @return [Symbol, Integer] HTTP status code
        attr_reader :http_status

        # Creates a new guard error with metadata.
        #
        # @param message [String, nil] error message
        # @param detail [String] machine-readable identifier for programmatic branching (default: 'guard_failed')
        # @param http_status [Symbol, Integer] HTTP status (default: :unprocessable_entity)
        def initialize(message = nil, detail: 'guard_failed', http_status: :unprocessable_entity)
          super(message, detail: detail)
          @http_status = http_status
        end
      end

      # --------------------------------------------------------
      # Standard HTTP error classes
      # --------------------------------------------------------

      # 400 Bad Request - malformed or invalid request data.
      class BadRequestError < ServiceError
        DEFAULT_MESSAGE = 'Bad request'

        def http_status = :bad_request
      end

      # 401 Unauthorized - authentication credentials missing or invalid.
      class AuthenticationError < ServiceError
        DEFAULT_MESSAGE = 'Authentication failed'

        def http_status = :unauthorized
      end

      # 401 Unauthorized (alias for AuthenticationError).
      class UnauthorizedError < AuthenticationError
        DEFAULT_MESSAGE = 'Unauthorized'
      end

      # 403 Forbidden - authenticated but not authorized.
      class ForbiddenError < ServiceError
        DEFAULT_MESSAGE = 'Forbidden'

        def http_status = :forbidden
      end

      # 404 Not Found - requested resource does not exist.
      class NotFoundError < ServiceError
        DEFAULT_MESSAGE = 'Not found'

        def http_status = :not_found
      end

      # 405 Method Not Allowed - HTTP method not supported for this resource.
      class MethodNotAllowedError < ServiceError
        DEFAULT_MESSAGE = 'Method not allowed'

        def http_status = :method_not_allowed
      end

      # 406 Not Acceptable - requested content type cannot be provided.
      class NotAcceptableError < ServiceError
        DEFAULT_MESSAGE = 'Not acceptable'

        def http_status = :not_acceptable
      end

      # 407 Proxy Authentication Required - proxy credentials required.
      class ProxyAuthenticationRequiredError < ServiceError
        DEFAULT_MESSAGE = 'Proxy authentication required'

        def http_status = :proxy_authentication_required
      end

      # 408 Request Timeout - client did not produce a request in time.
      class RequestTimeoutError < ServiceError
        DEFAULT_MESSAGE = 'Request timeout'

        def http_status = :request_timeout
      end

      # 409 Conflict - request conflicts with current state of the resource.
      class ConflictError < ServiceError
        DEFAULT_MESSAGE = 'Conflict'

        def http_status = :conflict
      end

      # 410 Gone - resource is no longer available and will not be available again.
      class GoneError < ServiceError
        DEFAULT_MESSAGE = 'Gone'

        def http_status = :gone
      end

      # 411 Length Required - Content-Length header is required.
      class LengthRequiredError < ServiceError
        DEFAULT_MESSAGE = 'Length required'

        def http_status = :length_required
      end

      # 412 Precondition Failed - precondition in headers evaluated to false.
      class PreconditionFailedError < ServiceError
        DEFAULT_MESSAGE = 'Precondition failed'

        def http_status = :precondition_failed
      end

      # 413 Payload Too Large - request entity is larger than server limits.
      class PayloadTooLargeError < ServiceError
        DEFAULT_MESSAGE = 'Payload too large'

        def http_status = :payload_too_large
      end

      # 414 URI Too Long - URI is too long for the server to process.
      class UriTooLongError < ServiceError
        DEFAULT_MESSAGE = 'URI too long'

        def http_status = :uri_too_long
      end

      # 415 Unsupported Media Type - request entity has unsupported media type.
      class UnsupportedMediaTypeError < ServiceError
        DEFAULT_MESSAGE = 'Unsupported media type'

        def http_status = :unsupported_media_type
      end

      # 416 Range Not Satisfiable - client requested a portion that cannot be supplied.
      class RangeNotSatisfiableError < ServiceError
        DEFAULT_MESSAGE = 'Range not satisfiable'

        def http_status = :range_not_satisfiable
      end

      # 417 Expectation Failed - server cannot meet Expect header requirements.
      class ExpectationFailedError < ServiceError
        DEFAULT_MESSAGE = 'Expectation failed'

        def http_status = :expectation_failed
      end

      # 418 I'm a Teapot - server refuses to brew coffee because it is a teapot.
      class ImATeapotError < ServiceError
        DEFAULT_MESSAGE = "I'm a teapot"

        def http_status = :im_a_teapot
      end

      # 421 Misdirected Request - request was directed at a server unable to respond.
      class MisdirectedRequestError < ServiceError
        DEFAULT_MESSAGE = 'Misdirected request'

        def http_status = :misdirected_request
      end

      # 422 Unprocessable Entity - semantic errors in request.
      class UnprocessableEntityError < ServiceError
        DEFAULT_MESSAGE = 'Unprocessable entity'

        def http_status = :unprocessable_entity
      end

      # 422 Unprocessable Content - content could not be processed.
      class UnprocessableContentError < UnprocessableEntityError
        DEFAULT_MESSAGE = 'Unprocessable content'

        def http_status = :unprocessable_content
      end

      # 422 Validation Error - schema or business validation failed.
      class ValidationError < UnprocessableEntityError
        DEFAULT_MESSAGE = 'Validation failed'
      end

      # 423 Locked - resource is locked.
      class LockedError < ServiceError
        DEFAULT_MESSAGE = 'Locked'

        def http_status = :locked
      end

      # 424 Failed Dependency - request failed due to failure of a previous request.
      class FailedDependencyError < ServiceError
        DEFAULT_MESSAGE = 'Failed dependency'

        def http_status = :failed_dependency
      end

      # 425 Too Early - server unwilling to process request that might be replayed.
      class TooEarlyError < ServiceError
        DEFAULT_MESSAGE = 'Too early'

        def http_status = :too_early
      end

      # 426 Upgrade Required - client should switch to a different protocol.
      class UpgradeRequiredError < ServiceError
        DEFAULT_MESSAGE = 'Upgrade required'

        def http_status = :upgrade_required
      end

      # 428 Precondition Required - origin server requires the request to be conditional.
      class PreconditionRequiredError < ServiceError
        DEFAULT_MESSAGE = 'Precondition required'

        def http_status = :precondition_required
      end

      # 429 Too Many Requests - user has sent too many requests in a given time.
      class TooManyRequestsError < ServiceError
        DEFAULT_MESSAGE = 'Too many requests'

        def http_status = :too_many_requests
      end

      # 431 Request Header Fields Too Large - server unwilling to process due to header size.
      class RequestHeaderFieldsTooLargeError < ServiceError
        DEFAULT_MESSAGE = 'Request header fields too large'

        def http_status = :request_header_fields_too_large
      end

      # 451 Unavailable For Legal Reasons - resource unavailable due to legal demands.
      class UnavailableForLegalReasonsError < ServiceError
        DEFAULT_MESSAGE = 'Unavailable for legal reasons'

        def http_status = :unavailable_for_legal_reasons
      end

      # 500 Internal Server Error - unexpected server-side failure.
      class InternalServerError < ServiceError
        DEFAULT_MESSAGE = 'Internal server error'

        def http_status = :internal_server_error
      end

      # 501 Not Implemented - server does not support the functionality required.
      class NotImplementedError < ServiceError
        DEFAULT_MESSAGE = 'Not implemented'

        def http_status = :not_implemented
      end

      # 502 Bad Gateway - server received an invalid response from upstream.
      class BadGatewayError < ServiceError
        DEFAULT_MESSAGE = 'Bad gateway'

        def http_status = :bad_gateway
      end

      # 503 Service Unavailable - dependency temporarily unavailable.
      class ServiceUnavailableError < ServiceError
        DEFAULT_MESSAGE = 'Service unavailable'

        def http_status = :service_unavailable
      end

      # 504 Gateway Timeout - upstream server did not respond in time.
      class GatewayTimeoutError < ServiceError
        DEFAULT_MESSAGE = 'Gateway timeout'

        def http_status = :gateway_timeout
      end

      # 505 HTTP Version Not Supported - server does not support the HTTP version.
      class HttpVersionNotSupportedError < ServiceError
        DEFAULT_MESSAGE = 'HTTP version not supported'

        def http_status = :http_version_not_supported
      end

      # 506 Variant Also Negotiates - transparent content negotiation error.
      class VariantAlsoNegotiatesError < ServiceError
        DEFAULT_MESSAGE = 'Variant also negotiates'

        def http_status = :variant_also_negotiates
      end

      # 507 Insufficient Storage - server unable to store the representation.
      class InsufficientStorageError < ServiceError
        DEFAULT_MESSAGE = 'Insufficient storage'

        def http_status = :insufficient_storage
      end

      # 508 Loop Detected - server detected an infinite loop while processing.
      class LoopDetectedError < ServiceError
        DEFAULT_MESSAGE = 'Loop detected'

        def http_status = :loop_detected
      end

      # 510 Not Extended - further extensions to the request are required.
      class NotExtendedError < ServiceError
        DEFAULT_MESSAGE = 'Not extended'

        def http_status = :not_extended
      end

      # 511 Network Authentication Required - client needs to authenticate for network access.
      class NetworkAuthenticationRequiredError < ServiceError
        DEFAULT_MESSAGE = 'Network authentication required'

        def http_status = :network_authentication_required
      end
    end
  end
end
