# frozen_string_literal: true

module Servus
  module Events
    # Default router that reads +invoke+ declarations from Event classes.
    #
    # ClassRouter is what ships with Servus and is the default when no
    # routers are configured. It resolves invocations by looking up all
    # Event classes registered for the given event name and calling
    # +invocations_for+ on each — which evaluates if/unless conditions
    # and returns Invocation objects for actions that should run.
    #
    # Applications can add additional routers (e.g. a data-driven router
    # backed by a database table) alongside the ClassRouter:
    #
    #   Servus.configure do |config|
    #     config.routers = [
    #       Servus::Events::ClassRouter.new,
    #       MyApp::DataDrivenRouter.new
    #     ]
    #   end
    #
    # @see Servus::Events::Router
    # @see Servus::Event#invocations_for
    class ClassRouter < Router
      # Resolves invocations by reading +invoke+ declarations from all
      # Event classes registered for the given event name.
      #
      # @param event_name [Symbol] the name of the emitted event
      # @param payload [Hash] the event payload
      # @return [Array<Servus::Events::Invocation>] invocations to execute
      def resolve(event_name, payload)
        Bus.handlers_for(event_name).flat_map do |event_class|
          event_class.invocations_for(payload)
        end
      end
    end
  end
end
