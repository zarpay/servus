# frozen_string_literal: true

require 'logger'
require 'active_support/parameter_filter'

module Servus
  module Support
    # Logger class for logging service calls and results
    class Logger
      # Returns the logger instance depending on the environment
      #
      # @return [Logger] The logger instance
      def self.logger
        if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
          Rails.logger
        else
          @logger ||= ::Logger.new($stdout)
        end
      end

      # Logs a call to a service.
      #
      # Argument values are filtered through
      # {Servus::Config#log_filter_parameters} so credentials (tokens,
      # passwords, auth hashes) never reach the log line.
      #
      # @param service_class [Class] The service class
      # @param args [Hash] The arguments passed to the service
      def self.log_call(service_class, args)
        logger.info("Calling #{service_class.name} with args: #{parameter_filter.filter(args).inspect}")
      end

      # Parameter filter built from the current configuration, rebuilt
      # whenever the configured filter list changes. The comparison snapshot
      # is a copy, so in-place mutation of the list also triggers a rebuild.
      #
      # @return [ActiveSupport::ParameterFilter]
      def self.parameter_filter
        filters = Servus.config.log_filter_parameters

        if @parameter_filter.nil? || @parameter_filter_source != filters
          @parameter_filter_source = filters.dup
          @parameter_filter = ActiveSupport::ParameterFilter.new(filters)
        end

        @parameter_filter
      end

      # Logs a result from a service
      #
      # @param service_class [Class] The service class
      # @param result [Servus::Support::Response] The result from the service
      # @param duration [Float] The duration of the service call
      def self.log_result(service_class, result, duration)
        if result.success?
          log_success(service_class, duration)
        else
          log_failure(service_class, result.error, duration)
        end
      end

      # Logs a successful result from a service
      #
      # @param service_class [Class] The service class
      # @param duration [Float] The duration of the service call
      def self.log_success(service_class, duration)
        logger.info("#{service_class.name} succeeded in #{duration.round(3)}s")
      end

      # Logs a failed result from a service
      #
      # @param service_class [Class] The service class
      # @param error [Servus::Support::Errors::ServiceError] The error from the service
      # @param duration [Float] The duration of the service call
      def self.log_failure(service_class, error, duration)
        logger.warn("#{service_class.name} failed in #{duration.round(3)}s with error: #{error}")
      end

      # Logs a guard failure from a service
      #
      # @param service_class [Class] The service class
      # @param error [Servus::Support::Errors::GuardError] The guard error
      def self.log_guard_failure(service_class, error)
        logger.warn("#{service_class.name} guard failed: #{error.message}")
      end

      # Logs an event emission with correlation ID and duration.
      #
      # @param event_name [Symbol] The event name
      # @param payload [Hash] The event payload
      # @param event_id [String] The unique event correlation ID
      # @param duration_ms [Float] The dispatch duration in milliseconds
      def self.log_event(event_name, payload, event_id:, duration_ms:)
        logger.info("[#{event_id}] Event :#{event_name} (#{duration_ms.round(1)}ms) #{payload.inspect}")
      end

      # Logs a validation error from a service
      #
      # @param service_class [Class] The service class
      # @param error [Servus::Support::Errors::ValidationError] The validation error
      def self.log_validation_error(service_class, error)
        logger.error("#{service_class.name} validation error: #{error.message}")
      end

      # Logs an uncaught exception from a service
      #
      # @param service_class [Class] The service class
      # @param exception [Exception] The uncaught exception
      def self.log_exception(service_class, exception)
        logger.error("#{service_class.name} uncaught exception: #{exception.class} - #{exception.message}")
      end
    end
  end
end
