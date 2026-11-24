# frozen_string_literal: true

module Servus
  module Support
    # Sends the call.servus notification around every service call, outside rescue_from.
    module Instrumentation
      def self.included(base)
        base.singleton_class.prepend(CallOverride)
      end

      # Prepended after Rescuer::CallOverride, so it wraps rescue_from.
      module CallOverride
        def call(**args)
          Instrumentation.instrument_call(self, args) { super }
        end
      end

      class << self
        def instrument_call(service, args, &)
          payload = { service:, args: Logger.log_parameters(args) }
          ActiveSupport::Notifications.instrument('call.servus', payload) { record_outcome(payload, &) }
        end

        def failed_check(error, outcome)
          failed_checks[-1] = [error, outcome] unless failed_checks.empty?
        end

        private

        def record_outcome(payload)
          failed_checks.push(nil)
          payload[:response] = yield
          payload[:outcome] = outcome_for(payload[:response])
          payload[:response]
        rescue StandardError => e
          payload[:outcome] = failed_check_outcome(e)
          raise
        ensure
          failed_checks.pop
        end

        def outcome_for(response)
          return :success if response.success?

          response.error.is_a?(Errors::GuardError) ? :guard : :failure
        end

        def failed_check_outcome(error)
          failed_error, outcome = failed_checks.last
          failed_error.equal?(error) ? outcome : :exception
        end

        def failed_checks
          ActiveSupport::IsolatedExecutionState[:servus_failed_checks] ||= []
        end
      end
    end
  end
end
