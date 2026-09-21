# frozen_string_literal: true

require 'logger'

module Servus
  module Support
    # Logger class for logging service calls and results
    class Logger
      # The logger Servus writes through: the one set in {Servus::Config#logger},
      # else `Rails.logger`, else a `$stdout` logger. Resolved on every read, so
      # Servus follows Rails if the application swaps its logger after boot.
      #
      # Lines about a service go to that service's {Servus::Base.logger} instead.
      #
      # @return [::Logger] The logger instance
      # @see Servus.logger
      def self.logger
        Servus.config.logger || rails_logger || stdout_logger
      end

      # Logs a call to a service.
      #
      # When {Servus::Config#log_filter_parameters} is configured, matching
      # argument values are replaced with `[FILTERED]` before logging. With
      # the default empty list, arguments are logged verbatim.
      #
      # @param service_class [Class] The service class
      # @param args [Hash] The arguments passed to the service
      def self.log_call(service_class, args)
        rendered = log_parameters(args)
        service_class.logger.info("Calling #{service_class.name} with args: #{rendered.inspect}")
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
        service_class.logger.info("#{service_class.name} succeeded in #{duration.round(3)}s")
      end

      # Logs a failed result from a service
      #
      # @param service_class [Class] The service class
      # @param error [Servus::Support::Errors::ServiceError] The error from the service
      # @param duration [Float] The duration of the service call
      def self.log_failure(service_class, error, duration)
        service_class.logger.warn("#{service_class.name} failed in #{duration.round(3)}s with error: #{error}")
      end

      # Logs a guard failure from a service
      #
      # @param service_class [Class] The service class
      # @param error [Servus::Support::Errors::GuardError] The guard error
      def self.log_guard_failure(service_class, error)
        service_class.logger.warn("#{service_class.name} guard failed: #{error.message}")
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
        service_class.logger.error("#{service_class.name} validation error: #{error.message}")
      end

      # Logs an uncaught exception from a service
      #
      # @param service_class [Class] The service class
      # @param exception [Exception] The uncaught exception
      def self.log_exception(service_class, exception)
        service_class.logger.error(
          "#{service_class.name} uncaught exception: #{exception.class} - #{exception.message}"
        )
      end

      # Logs that a registered schema fragment was replaced with a different value.
      #
      # Expected during development reloads. Outside of that it usually means
      # two libraries are claiming the same fragment key.
      #
      # @param key [String] The schema fragment key being overridden
      def self.log_schema_override(key)
        logger.warn("Schema fragment #{key.inspect} was already registered with a different value; replacing it.")
      end

      # Logs that a service could not publish its generated job class because the
      # constant is already taken by the application.
      #
      # The application's class is left alone. The service still runs, but its
      # generated job has no name, so +call_async+ on it cannot be serialized.
      #
      # @param service_class [Class<Servus::Base>] The service whose job was not published
      # @param const_name [String] The constant the application already owns
      def self.log_job_class_conflict(service_class, const_name)
        service_class.logger.warn(
          "#{service_class.name} did not publish its generated job as #{const_name} — that constant " \
          'is already defined by the application. The application class is unchanged; ' \
          "#{service_class.name}.call_async cannot be enqueued until the service or the job is renamed."
        )
      end

      # Filters parameters for logging based on the configured filter list.
      #
      # @param params [Hash] The parameters to filter
      # @return [Hash] The filtered parameters
      def self.log_parameters(params)
        if Servus.config.log_filter_parameters.empty?
          params
        else
          Servus.config.parameter_filter.filter(params)
        end
      end

      # @return [::Logger, nil] Rails' logger, when Rails is loaded and has one
      def self.rails_logger
        Rails.logger if defined?(Rails) && Rails.respond_to?(:logger)
      end
      private_class_method :rails_logger

      # @return [::Logger] the fallback logger, built once
      def self.stdout_logger
        @stdout_logger ||= ::Logger.new($stdout)
      end
      private_class_method :stdout_logger
    end
  end
end
