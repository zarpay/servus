# frozen_string_literal: true

module Servus
  # Base class for all services
  class Base
    include Servus::Support::Errors
    include Servus::Support::Rescuer

    # Support class aliases
    Logger = Servus::Support::Logger
    Response = Servus::Support::Response
    Validator = Servus::Support::Validator

    # Calls the service and returns a response
    #
    # @param args [Hash] The arguments to pass to the service
    # @return [Servus::Support::Response] The response
    # @raise [StandardError] If an exception is raised
    # @raise [Servus::Support::Errors::ValidationError] If result is invalid
    # @raise [Servus::Support::Errors::ValidationError] If arguments are invalid
    def self.call(**args)
      before_call(args)
      result = benchmark(**args) { new(**args).call }
      after_call(result)

      result
    rescue ValidationError => e
      Logger.log_validation_error(self, e)
      raise e
    rescue StandardError => e
      Logger.log_exception(self, e)
      raise e
    end

    # Returns a success response
    #
    # @param data [Object] The data to return
    # @return [Servus::Support::Response] The success response
    def success(data)
      Response.new(true, data, nil)
    end

    # Returns a failure response
    #
    # @param message [String] The error message
    # @param type [Class] The error type
    # @return [Servus::Support::Response] The failure response
    def failure(message = nil, type: Servus::Support::Errors::ServiceError)
      error = type.new(message)
      Response.new(false, nil, error)
    end

    # Raises an error and logs it
    #
    # @param message [String] The error message
    # @param type [Class] The error type
    # @return [void]
    def error!(message = nil, type: Servus::Support::Errors::ServiceError)
      Logger.log_exception(self.class, type.new(message))
      raise type, message
    end

    # Runs call setup before call
    #
    # @param args [Hash] The arguments to pass to the service
    # @return [Object] The result of the call
    def self.before_call(args)
      Logger.log_call(self, args)
      Validator.validate_arguments!(self, args)
    end

    # Runs after call
    #
    # @param args [Hash] The arguments to pass to the service
    # @return [Object] The result of the call
    def self.after_call(args)
      Validator.validate_result!(self, args)
    end

    # Benchmarks the call
    #
    # @param args [Hash] The arguments to pass to the service
    # @return [Object] The result of the call
    def self.benchmark(**_args)
      start_time = Time.now.utc
      result = yield
      duration = Time.now.utc - start_time

      Logger.log_result(self, result, duration)

      result
    end
  end
end
