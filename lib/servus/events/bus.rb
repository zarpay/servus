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
    # @example Registering a handler
    #   class UserCreatedHandler < Servus::EventHandler
    #     handles :user_created
    #   end
    #
    #   Servus::Events::Bus.register_handler(:user_created, UserCreatedHandler)
    #
    # @example Retrieving handlers for an event
    #   handlers = Servus::Events::Bus.handlers_for(:user_created)
    #   handlers.each { |handler| handler.handle(payload) }
    #
    # @example Instrumentation in logs
    #   Bus.emit(:user_created, user_id: 123)
    #   # Rails log: servus.events.user_created (1.2ms) {:user_id=>123}
    #
    # @see Servus::EventHandler
    class Bus
      class << self
        # Registers a handler class for a specific event.
        #
        # Multiple handlers can be registered for the same event, and they
        # will all be invoked when the event is emitted. The handler is
        # automatically subscribed to ActiveSupport::Notifications.
        #
        # Handlers are typically registered automatically when EventHandler
        # classes are loaded at boot time via the `handles` DSL method.
        #
        # @param event_name [Symbol] the name of the event
        # @param handler_class [Class] the handler class to register
        # @return [Array] the updated array of handlers for this event
        #
        # @example
        #   Bus.register_handler(:user_created, UserCreatedHandler)
        def register_handler(event_name, handler_class)
          handlers[event_name] ||= []
          handlers[event_name] << handler_class

          # Subscribe to ActiveSupport::Notifications
          subscription = ActiveSupport::Notifications.subscribe(notification_name(event_name)) do |*args|
            event = ActiveSupport::Notifications::Event.new(*args)
            handler_class.handle(event.payload)
          end

          # Store subscription for cleanup
          subscriptions[event_name] ||= []
          subscriptions[event_name] << subscription
        end

        # Retrieves all registered handlers for a specific event.
        #
        # Returns a duplicate array to prevent external modification of the
        # internal handler registry.
        #
        # @param event_name [Symbol] the name of the event
        # @return [Array<Class>] array of handler classes registered for this event
        #
        # @example
        #   handlers = Bus.handlers_for(:user_created)
        #   handlers.each { |handler| handler.handle(payload) }
        def handlers_for(event_name)
          (handlers[event_name] || []).dup
        end

        # Emits an event to all registered handlers with instrumentation.
        #
        # Uses ActiveSupport::Notifications to instrument the event, providing
        # automatic timing and logging. The event will appear in Rails logs
        # with duration and payload information.
        #
        # @param event_name [Symbol] the name of the event to emit
        # @param payload [Hash] the event payload to pass to handlers
        # @return [void]
        #
        # @example
        #   Bus.emit(:user_created, { user_id: 123, email: 'user@example.com' })
        #   # Rails log: servus.events.user_created (1.2ms) {:user_id=>123, :email=>"user@example.com"}
        def emit(event_name, payload)
          ActiveSupport::Notifications.instrument(notification_name(event_name), payload)
        end

        # Clears all registered handlers and unsubscribes from notifications.
        #
        # Useful for testing and development mode reloading.
        #
        # @return [void]
        #
        # @example
        #   Bus.clear
        def clear
          subscriptions.values.flatten.each do |subscription|
            ActiveSupport::Notifications.unsubscribe(subscription)
          end

          @handlers = nil
          @subscriptions = nil
        end

        private

        # Hash storing event handlers.
        #
        # @return [Hash] hash mapping event names to handler arrays
        def handlers
          @handlers ||= {}
        end

        # Hash storing ActiveSupport::Notifications subscriptions.
        #
        # @return [Hash] hash mapping event names to subscription objects
        def subscriptions
          @subscriptions ||= {}
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
