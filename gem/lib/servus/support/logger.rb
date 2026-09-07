# frozen_string_literal: true

module Servus
  module Support
    # Writes every line Servus logs about one service call.
    #
    # Built by {Servus::Base.call} for the service it is about, so the
    # service class is the object's identity rather than an argument on
    # every method. Lines go to {Servus::Base.logger}, which a service
    # class can set for itself.
    #
    # Lines that belong to no service — event emission, schema fragment
    # overrides — are written at their call sites through {Servus.logger}.
    #
    # @api private
    class Logger
      # @param service_class [Class] the service the lines are about
      def initialize(service_class)
        @service_class = service_class
      end

      # Logs a call to the service.
      #
      # When {Servus::Config#log_filter_parameters} is configured, matching
      # argument values are replaced with `[FILTERED]`. With the default
      # empty list, arguments are logged verbatim.
      #
      # @param args [Hash] the arguments passed to the service
      # @return [void]
      def call(args)
        logger.info("Calling #{name} with args: #{filtered(args).inspect}")
      end

      # Logs the outcome of the call.
      #
      # @param result [Servus::Support::Response] the response the service returned
      # @param duration [Float] the duration of the call in seconds
      # @return [void]
      def result(result, duration)
        if result.success?
          success(duration)
        else
          failure(result.error, duration)
        end
      end

      # @param duration [Float] the duration of the call in seconds
      # @return [void]
      def success(duration)
        logger.info("#{name} succeeded in #{duration.round(3)}s")
      end

      # @param error [Servus::Support::Errors::ServiceError] the error the service returned
      # @param duration [Float] the duration of the call in seconds
      # @return [void]
      def failure(error, duration)
        logger.warn("#{name} failed in #{duration.round(3)}s with error: #{error}")
      end

      # @param error [Servus::Support::Errors::GuardError] the guard error
      # @return [void]
      def guard_failure(error)
        logger.warn("#{name} guard failed: #{error.message}")
      end

      # @param error [Servus::Support::Errors::ValidationError] the validation error
      # @return [void]
      def validation_error(error)
        logger.error("#{name} validation error: #{error.message}")
      end

      # @param error [Exception] the uncaught exception
      # @return [void]
      def exception(error)
        logger.error("#{name} uncaught exception: #{error.class} - #{error.message}")
      end

      # Logs that the service could not publish its generated job class because
      # the application already owns the constant.
      #
      # The application's class is left alone. The service still runs, but its
      # generated job has no name, so +call_async+ on it cannot be serialized.
      #
      # @param const_name [String] the constant the application already owns
      # @return [void]
      def job_class_conflict(const_name)
        logger.warn(
          "#{name} did not publish its generated job as #{const_name} — that constant " \
          'is already defined by the application. The application class is unchanged; ' \
          "#{name}.call_async cannot be enqueued until the service or the job is renamed."
        )
      end

      private

      # @return [String] the name of the service the lines are about
      def name
        @service_class.name
      end

      # @return [::Logger] the logger the service class writes through
      def logger
        @service_class.logger
      end

      # @param params [Hash] the arguments to filter
      # @return [Hash] the arguments with configured keys masked
      def filtered(params)
        return params if Servus.config.log_filter_parameters.empty?

        Servus.config.parameter_filter.filter(params)
      end
    end
  end
end
