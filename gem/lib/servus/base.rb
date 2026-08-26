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
    include Servus::Support::Lockdown
    include Servus::Events::Emitter
    include Servus::Guards

    extend Servus::Schema::Declaration

    # @!method self.schema(arguments: nil, result: nil, failure: nil)
    #   Declares the JSON schemas used to validate this service.
    #
    #   Arguments are validated before +call+ runs, so the body can trust the
    #   shape of its inputs. Result data is validated after it returns, so a
    #   service that stops honouring its own contract fails loudly rather than
    #   shipping the wrong shape to its callers.
    #
    #   Schemas may reference shared fragments registered with
    #   {Servus::Schema.register}; refs are resolved on first read.
    #
    #   Omitting a keyword leaves any schema declared earlier — or by a
    #   superclass — in place. Passing one explicitly as +nil+ raises.
    #
    #   @param arguments [Hash] JSON schema for the service's arguments
    #   @param result [Hash] JSON schema for successful result data
    #   @param failure [Hash] JSON schema for failure response data
    #   @return [void]
    #   @raise [ArgumentError] on an unknown keyword or an explicit nil
    #
    #   @example Declaring arguments and result schemas
    #     class ProcessPayment::Service < Servus::Base
    #       schema(
    #         arguments: {
    #           type: 'object',
    #           required: ['user_id', 'amount'],
    #           properties: {
    #             user_id: { type: 'integer' },
    #             amount: { type: 'number', minimum: 0.01 }
    #           }
    #         },
    #         result: {
    #           type: 'object',
    #           required: ['transaction_id'],
    #           properties: { transaction_id: { type: 'string' } }
    #         }
    #       )
    #     end
    #
    #   @example Referencing a shared fragment
    #     schema arguments: {
    #       type: 'object',
    #       properties: { amount: { '$ref' => '#/core/$defs/amount' } }
    #     }
    #
    #   @see Servus::Schema
    #
    # @!method self.arguments_schema
    #   @return [Hash, nil] the compiled arguments schema
    # @!method self.result_schema
    #   @return [Hash, nil] the compiled result schema
    # @!method self.failure_schema
    #   @return [Hash, nil] the compiled failure schema
    # @!method self.raw_arguments_schema
    #   @return [Hash, nil] the arguments schema as authored, refs unresolved
    # @!method self.raw_result_schema
    #   @return [Hash, nil] the result schema as authored, refs unresolved
    # @!method self.raw_failure_schema
    #   @return [Hash, nil] the failure schema as authored, refs unresolved
    declare_schemas :arguments, :result, :failure

    # Support class aliases
    Logger = Servus::Support::Logger
    Emitter = Servus::Events::Emitter
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
    # @param data [Object, nil] optional structured data to attach to the failure response.
    #   When a +failure+ schema is defined, this data will be validated against it.
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
    # @example Attaching structured data to a failure
    #   def call
    #     return failure("Approval required", data: { requires_human_approval: true })
    #   end
    #
    # @see #success
    # @see #error!
    # @see Servus::Support::Errors
    def failure(message = nil, data: nil, type: Servus::Support::Errors::ServiceError)
      error = type.new(message)
      Response.new(false, data, error)
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
      error = type.new(message)
      Logger.log_exception(self.class, error)

      # Emit error! events before raising
      emit_events_for(:error!, Response.new(false, nil, error))

      raise type, message
    end

    # Invokes another service from within this service's {#call} and returns its
    # data on success. On failure, halts the outer service with the sub-service's
    # failure Response — the outer service's caller receives that Response
    # unchanged (same error object, message, code, http_status).
    #
    # Sugar over:
    #
    #   result = SubService.call(**params)
    #   return result unless result.success?
    #   data = result.data
    #
    # Only call from within a service's `#call` (or helpers reachable from
    # it); the throw is caught by {Servus::Base.call}.
    #
    # @example Composing services
    #   class SendDigitalCash::Service < Servus::Base
    #     def call
    #       data1 = call!(Accounts::Lookup::Service, id: account_id)
    #       data2 = call!(Ledger::RecordTransfer::Service, account:, amount:)
    #       success(ref: data2.ref)
    #     end
    #   end
    #
    # For invoking a service from *outside* a service context (controllers,
    # rake tasks, jobs, consoles), see
    # {Servus::Helpers::ControllerHelpers#run_service!}.
    #
    # @param service_class [Class<Servus::Base>] the sub-service to invoke
    # @param params [Hash] keyword arguments to pass to the sub-service
    # @return [Servus::Support::DataObject, Object] the sub-service's data on success
    # @throw [:guard_failure, Servus::Support::Response] the failure Response, otherwise
    #
    # @see Servus::Helpers::ControllerHelpers#run_service!
    def call!(service_class, **params)
      result = service_class.call(**params)
      return result.data if result.success?

      throw(:guard_failure, result)
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
      #
      # rubocop:disable Metrics/MethodLength
      def call(**args)
        before_call(args)

        instance = new(**args)

        # Wrap execution in catch block to handle guard failures
        result = catch(:guard_failure) do
          benchmark(**args) { instance.send(:call) }
        end

        if result.is_a?(Servus::Support::Errors::GuardError)
          Logger.log_guard_failure(self, result)
          result = Response.new(false, nil, result)
        end

        after_call(result, instance)

        result
      rescue Servus::Support::Errors::ValidationError => e
        Logger.log_validation_error(self, e)
        raise e
      rescue StandardError => e
        Logger.log_exception(self, e)
        raise e
      end
      # rubocop:enable Metrics/MethodLength

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

      # Executes post-call hooks including result validation and event emission.
      #
      # This method is automatically called after service execution completes and handles:
      # - Validating the result data against RESULT_SCHEMA (if defined)
      # - Emitting events declared with the emits DSL
      #
      # @param result [Servus::Support::Response] the response returned from the service
      # @param instance [Servus::Base] the service instance
      # @return [void]
      # @raise [Servus::Support::Errors::ValidationError] if result data fails validation
      #
      # @api private
      def after_call(result, instance)
        Validator.validate_result!(self, result)
        Emitter.emit_result_events!(instance, result)
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
