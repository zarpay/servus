# frozen_string_literal: true

module Servus
  # Base class for all service objects in the Servus framework.
  #
  # This class provides the foundational functionality for implementing the Service Object pattern,
  # including automatic validation, logging, benchmarking, and error handling.
  #
  # @abstract Subclass and implement initialize and call methods to create a service
  #
  # @example Creating a basic service
  #   class Services::ProcessPayment::Service < Servus::Base
  #     def initialize(user:, amount:, payment_method:)
  #       @user = user
  #       @amount = amount
  #       @payment_method = payment_method
  #     end
  #
  #     def call
  #       return failure("Invalid amount") if @amount <= 0
  #
  #       transaction = charge_payment
  #       success({ transaction_id: transaction.id })
  #     end
  #
  #     private
  #
  #     def charge_payment
  #       # Payment processing logic
  #     end
  #   end
  #
  # @example Using a service
  #   result = Services::ProcessPayment::Service.call(
  #     user: current_user,
  #     amount: 100,
  #     payment_method: "credit_card"
  #   )
  #
  #   if result.success?
  #     puts "Transaction ID: #{result.data[:transaction_id]}"
  #   else
  #     puts "Error: #{result.error.message}"
  #   end
  #
  # @see Servus::Support::Response
  # @see Servus::Support::Errors
  class Base
    include Servus::Support::Errors
    include Servus::Support::Rescuer

    # Support class aliases
    Logger = Servus::Support::Logger
    Response = Servus::Support::Response
    Validator = Servus::Support::Validator

    # Creates a successful response with the provided data.
    #
    # Use this method to return successful results from your service's call method.
    # The data will be validated against the RESULT_SCHEMA if one is defined.
    #
    # @param data [Object] the data to return in the response (typically a Hash)
    # @return [Servus::Support::Response] response with success: true and the provided data
    #
    # @example Returning simple data
    #   def call
    #     success({ user_id: 123, status: "active" })
    #   end
    #
    # @example Returning nil for operations without data
    #   def call
    #     perform_action
    #     success(nil)
    #   end
    #
    # @see #failure
    # @see Servus::Support::Response
    def success(data)
      Response.new(true, data, nil)
    end

    # Creates a failure response with an error.
    #
    # Use this method to return failure results from your service's call method.
    # The failure is logged automatically and returns a response containing the error.
    #
    # @param message [String, nil] custom error message (uses error type's default if nil)
    # @param type [Class] error class to instantiate (must inherit from ServiceError)
    # @return [Servus::Support::Response] response with success: false and the error
    #
    # @example Using default error type with custom message
    #   def call
    #     return failure("User not found") unless user_exists?
    #     # ...
    #   end
    #
    # @example Using custom error type
    #   def call
    #     return failure("Invalid payment", type: Servus::Support::Errors::BadRequestError)
    #     # ...
    #   end
    #
    # @example Using error type's default message
    #   def call
    #     return failure(type: Servus::Support::Errors::NotFoundError)
    #     # Uses "Not found" as the message
    #   end
    #
    # @see #success
    # @see #error!
    # @see Servus::Support::Errors
    def failure(message = nil, type: Servus::Support::Errors::ServiceError)
      error = type.new(message)
      Response.new(false, nil, error)
    end

    # Logs an error and raises an exception, halting service execution.
    #
    # Use this method when you need to immediately halt execution with an exception
    # rather than returning a failure response. The error is automatically logged before
    # the exception is raised.
    #
    # @param message [String, nil] error message for the exception (uses default if nil)
    # @param type [Class] error class to raise (must inherit from ServiceError)
    # @return [void]
    # @raise [Servus::Support::Errors::ServiceError] the specified error type
    #
    # @example Raising an error with custom message
    #   def call
    #     error!("Critical system failure") if system_down?
    #   end
    #
    # @example Raising with specific error type
    #   def call
    #     error!("Unauthorized access", type: Servus::Support::Errors::UnauthorizedError)
    #   end
    #
    # @note Prefer {#failure} for expected error conditions. Use this for exceptional cases.
    # @see #failure
    def error!(message = nil, type: Servus::Support::Errors::ServiceError)
      Logger.log_exception(self.class, type.new(message))
      raise type, message
    end

    class << self
      # Executes the service with automatic validation, logging, and benchmarking.
      #
      # This is the primary entry point for executing services. It handles the complete
      # service lifecycle including:
      # - Input argument validation against schema
      # - Service instantiation
      # - Execution timing/benchmarking
      # - Result validation against schema
      # - Automatic logging of calls, results, and errors
      #
      # @param args [Hash] keyword arguments passed to the service's initialize method
      # @return [Servus::Support::Response] response object with success status and data or error
      #
      # @raise [Servus::Support::Errors::ValidationError] if input arguments fail schema validation
      # @raise [Servus::Support::Errors::ValidationError] if result data fails schema validation
      # @raise [StandardError] if an uncaught exception occurs during execution
      #
      # @example Successful execution
      #   result = MyService.call(user_id: 123, amount: 50)
      #   result.success? # => true
      #   result.data # => { transaction_id: "abc123" }
      #
      # @example Failed execution
      #   result = MyService.call(user_id: 123, amount: -10)
      #   result.success? # => false
      #   result.error.message # => "Amount must be positive"
      #
      # @see #initialize
      # @see #call
      def call(**args)
        before_call(args)
        result = benchmark(**args) { new(**args).call }
        after_call(result)

        result
      rescue Servus::Support::Errors::ValidationError => e
        Logger.log_validation_error(self, e)
        raise e
      rescue StandardError => e
        Logger.log_exception(self, e)
        raise e
      end

      # Defines schema validation rules for the service's arguments and/or result.
      #
      # This method provides a clean DSL for specifying JSON schemas that will be used
      # to validate service inputs and outputs. Schemas defined via this method take
      # precedence over ARGUMENTS_SCHEMA and RESULT_SCHEMA constants. The next major
      # version will deprecate those constants in favor of this DSL.
      #
      # @param arguments [Hash, nil] JSON schema for validating service arguments
      # @param result [Hash, nil] JSON schema for validating service result data
      # @return [void]
      #
      # @example Defining both arguments and result schemas
      #   class ProcessPayment::Service < Servus::Base
      #     schema(
      #       arguments: {
      #         type: 'object',
      #         required: ['user_id', 'amount'],
      #         properties: {
      #           user_id: { type: 'integer' },
      #           amount: { type: 'number', minimum: 0.01 }
      #         }
      #       },
      #       result: {
      #         type: 'object',
      #         required: ['transaction_id'],
      #         properties: {
      #           transaction_id: { type: 'string' }
      #         }
      #       }
      #     )
      #   end
      #
      # @example Defining only arguments schema
      #   class SendEmail::Service < Servus::Base
      #     schema arguments: { type: 'object', required: ['email', 'subject'] }
      #   end
      #
      # @see Servus::Support::Validator
      def schema(arguments: nil, result: nil)
        @arguments_schema = arguments.with_indifferent_access if arguments
        @result_schema    = result.with_indifferent_access    if result
      end

      # Returns the arguments schema defined via the schema DSL method.
      #
      # @return [Hash, nil] the arguments schema or nil if not defined
      # @api private
      attr_reader :arguments_schema

      # Returns the result schema defined via the schema DSL method.
      #
      # @return [Hash, nil] the result schema or nil if not defined
      # @api private
      attr_reader :result_schema

      # Executes pre-call hooks including logging and argument validation.
      #
      # This method is automatically called before service execution and handles:
      # - Logging the service call with arguments
      # - Validating arguments against ARGUMENTS_SCHEMA (if defined)
      #
      # @param args [Hash] keyword arguments being passed to the service
      # @return [void]
      # @raise [Servus::Support::Errors::ValidationError] if arguments fail validation
      #
      # @api private
      def before_call(args)
        Logger.log_call(self, args)
        Validator.validate_arguments!(self, args)
      end

      # Executes post-call hooks including result validation.
      #
      # This method is automatically called after service execution completes and handles:
      # - Validating the result data against RESULT_SCHEMA (if defined)
      #
      # @param result [Servus::Support::Response] the response returned from the service
      # @return [void]
      # @raise [Servus::Support::Errors::ValidationError] if result data fails validation
      #
      # @api private
      def after_call(result)
        Validator.validate_result!(self, result)
      end

      # Measures service execution time and logs the result.
      #
      # This method wraps the service execution to capture timing metrics.
      # The duration is logged along with the success/failure status of the service.
      #
      # @param _args [Hash] keyword arguments (unused, kept for method signature compatibility)
      # @yieldreturn [Servus::Support::Response] the result from executing the service
      # @return [Servus::Support::Response] the service execution result
      #
      # @api private
      def benchmark(**_args)
        start_time = Time.now.utc
        result = yield
        duration = Time.now.utc - start_time

        Logger.log_result(self, result, duration)

        result
      end
    end
  end
end
