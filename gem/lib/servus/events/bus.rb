# frozen_string_literal: true

module Servus
  module Events
    # Thread-safe event bus for registering and dispatching event handlers.
    #
    # The Bus acts as a central registry that maps event names to their
    # corresponding handler classes. It uses ActiveSupport::Notifications
    # internally to provide instrumentation and thread-safe event dispatch.
    #
    # Events are automatically instrumented and will appear in Rails logs
    # with timing information, making it easy to monitor event performance.
    #
    # @example Registering an event class
    #   class UserCreated < Servus::Event
    #     event_name :user_created
    #   end
    #
    #   Servus::Events::Bus.register_handler(:user_created, UserCreated)
    #
    # @example Retrieving event classes for an event
    #   events = Servus::Events::Bus.handlers_for(:user_created)
    #   events.each { |event_class| event_class.handle(payload) }
    #
    # @example Instrumentation in logs
    #   Bus.emit(:user_created, user_id: 123)
    #   # Rails log: servus.events.user_created (1.2ms) {:user_id=>123}
    #
    # @see Servus::Event
    class Bus
      class << self
        # Registers an Event class for a specific event name.
        #
        # Each event name maps to exactly one Event class. Attempting to
        # register a second class for the same name raises an error.
        #
        # Event classes are typically registered automatically at boot time
        # via the +event_name+ DSL method or +ensure_registered!+.
        #
        # @param name [Symbol] the event name
        # @param event_class [Class] the Event subclass to register
        # @return [void]
        # @raise [RuntimeError] if the event name is already registered
        #
        # @example
        #   Bus.register_event(:user_created, UserCreated)
        def register_event(name, event_class)
          if events.key?(name)
            raise "Event :#{name} is already registered to #{events[name]}. Cannot register #{event_class}"
          end

          events[name] = event_class
        end

        # Returns the Event class registered for the given name.
        #
        # @param name [Symbol] the event name
        # @return [Class, nil] the Event class or nil if not registered
        #
        # @example
        #   event_class = Bus.event_for(:user_created)
        #   event_class.invocations_for(payload)
        def event_for(name)
          events[name]
        end

        # Emits an event through the configured routers.
        #
        # Collects invocations from all routers (in config array order),
        # deduplicates by key (first wins), and executes each. The entire
        # dispatch is wrapped in ActiveSupport::Notifications so that
        # +subscribe_all+ listeners receive timing information.
        #
        # @param event_name [Symbol] the name of the event to emit
        # @param payload [Hash] the event payload
        # @return [void]
        #
        # @example
        #   Bus.emit(:user_created, { user_id: 123, email: 'user@example.com' })
        #   # Rails log: servus.events.user_created (1.2ms) {:user_id=>123, :email=>"user@example.com"}
        def emit(event_name, payload)
          ActiveSupport::Notifications.instrument(notification_name(event_name), payload) do
            resolve_invocations(event_name, payload)
              .uniq(&:key)
              .each(&:execute)
          end
        end

        # Subscribes to all Servus event emissions.
        #
        # Yields the clean event name and payload as positional args, plus
        # +started_at+, +finished_at+, and +id+ as keyword args.
        # Returns the subscription for manual unsubscribe.
        #
        # @yield [event_name, payload, started_at:, finished_at:, id:]
        # @yieldparam event_name [Symbol] the event name
        # @yieldparam payload [Hash] the event payload
        # @yieldparam started_at [Time] when the event was emitted
        # @yieldparam finished_at [Time] when the instrumented block completed
        # @yieldparam id [String] unique notification ID
        # @return [Object] the ActiveSupport::Notifications subscription
        #
        # @example Forward all events to an external system
        #   Servus::Events::Bus.subscribe_all do |event_name, payload, started_at:, **|
        #     EventusForwardJob.perform_later(
        #       event: event_name.to_s,
        #       payload: payload.as_json,
        #       occurred_at: started_at.utc.iso8601(6)
        #     )
        #   end
        def subscribe_all(&block)
          ActiveSupport::Notifications.subscribe(/^servus\.events\./) do |name, started, finished, id, payload|
            event_name = name.delete_prefix('servus.events.').to_sym
            block.call(event_name, payload, started_at: started, finished_at: finished, id: id)
          end
        end

        # Clears all registered events.
        #
        # Useful for testing and development mode reloading.
        #
        # @return [void]
        #
        # @example
        #   Bus.clear
        def clear
          @events = nil
        end

        private

        # Collects invocations from all configured routers.
        #
        # @param event_name [Symbol] the event name
        # @param payload [Hash] the event payload
        # @return [Array<Servus::Events::Invocation>]
        def resolve_invocations(event_name, payload)
          Servus.config.routers.flat_map { |router| router.resolve(event_name, payload) }
        end

        # @return [Hash{Symbol => Class}] event name to Event class mapping
        def events
          @events ||= {}
        end

        # Converts an event name to a namespaced notification name.
        #
        # @param event_name [Symbol] the event name
        # @return [String] the namespaced notification name
        def notification_name(event_name)
          "servus.events.#{event_name}"
        end
      end
    end
  end
end
