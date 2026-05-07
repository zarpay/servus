# frozen_string_literal: true

module Servus
  module Events
    # Abstract base class for event routers.
    #
    # Routers resolve which services should be invoked when an event fires.
    # The Bus iterates all configured routers (in order), collects the
    # Invocation objects they return, deduplicates by key, and executes.
    #
    # Servus ships one built-in router — ClassRouter — which reads the
    # +invoke+ declarations from Event classes. Applications can add their
    # own routers (e.g. a data-driven router backed by a database table)
    # by subclassing Router and implementing +#resolve+.
    #
    # Configure routers in the Servus initializer:
    #
    #   Servus.configure do |config|
    #     config.routers = [
    #       Servus::Events::ClassRouter.new,
    #       MyApp::DataDrivenRouter.new
    #     ]
    #   end
    #
    # @see Servus::Events::ClassRouter
    # @see Servus::Events::Invocation
    # @see Servus::Events::Bus
    class Router
      # Resolves which service invocations should run for the given event.
      #
      # Implementations must evaluate any conditions (if/unless) internally
      # and return only invocations that *will* run. The Bus does not
      # perform further filtering.
      #
      # @param event_name [Symbol] the name of the emitted event
      # @param payload [Hash] the event payload
      # @return [Array<Servus::Events::Invocation>] invocations to execute
      # @raise [NotImplementedError] when called on the abstract base class
      def resolve(event_name, payload)
        raise NotImplementedError, "#{self.class}#resolve must be implemented"
      end
    end
  end
end
