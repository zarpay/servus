# frozen_string_literal: true

module Servus
  module Support
    # Sends the call.servus notification around every service call, outside rescue_from.
    # Does no work unless something subscribes to call.servus.
    module Instrumentation
      def self.included(base)
        base.singleton_class.prepend(CallOverride)
      end

      # Prepended after Rescuer::CallOverride, so it wraps rescue_from.
      module CallOverride
        def call(**args)
          return super unless ActiveSupport::Notifications.notifier.listening?('call.servus')

          # The outcome stays :exception unless the call returns a response,
          # so a raise or a throw out of the call reports :exception.
          payload = { service: self, args: Logger.log_parameters(args), outcome: :exception }
          ActiveSupport::Notifications.instrument('call.servus', payload) do
            payload[:response] = super
            payload[:outcome] = Instrumentation.outcome_for(payload[:response])
            payload[:response]
          end
        end
      end

      # @param response [Servus::Support::Response]
      # @return [Symbol] :success, :failure or :guard
      def self.outcome_for(response)
        return :success if response.success?

        response.error.is_a?(Errors::GuardError) ? :guard : :failure
      end
    end
  end
end
