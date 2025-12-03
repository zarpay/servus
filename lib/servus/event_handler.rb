# frozen_string_literal: true

module Servus
  # Base class for event handlers that map events to service invocations.
  #
  # EventHandler classes live in app/events/ and use a declarative DSL to
  # subscribe to events and invoke services in response. Each handler
  # subscribes to a single event via the `handles` method.
  #
  # @example Basic event handler
  #   class UserCreatedHandler < Servus::EventHandler
  #     handles :user_created
  #
  #     invoke SendWelcomeEmail::Service, async: true do |payload|
  #       { user_id: payload[:user_id] }
  #     end
  #   end
  #
  # @see Servus::Events::Bus
  # @see Servus::Base
  class EventHandler
    class << self
      # Declares which event this handler subscribes to.
      #
      # This method registers the handler with the event bus and stores
      # the event name for later reference. Each handler can only subscribe
      # to one event.
      #
      # @param event_name [Symbol] the name of the event to handle
      # @return [void]
      # @raise [RuntimeError] if handles is called multiple times
      #
      # @example
      #   class UserCreatedHandler < Servus::EventHandler
      #     handles :user_created
      #   end
      def handles(event_name)
        raise "Handler already subscribed to :#{@event_name}. Cannot subscribe to :#{event_name}" if @event_name

        @event_name = event_name
        Servus::Events::Bus.register_handler(event_name, self)
      end

      # Returns the event name this handler is subscribed to.
      #
      # @return [Symbol, nil] the event name or nil if not yet configured
      attr_reader :event_name

      # Declares a service invocation in response to the event.
      #
      # Multiple invocations can be declared for a single event. Each invocation
      # requires a block that maps the event payload to the service's arguments.
      #
      # @param service_class [Class] the service class to invoke (must inherit from Servus::Base)
      # @param options [Hash] invocation options
      # @option options [Boolean] :async invoke the service asynchronously via call_async
      # @option options [Symbol] :queue the queue name for async jobs
      # @option options [Proc] :if condition that must return true for invocation
      # @option options [Proc] :unless condition that must return false for invocation
      # @yield [payload] block that maps event payload to service arguments
      # @yieldparam payload [Hash] the event payload
      # @yieldreturn [Hash] keyword arguments for the service's initialize method
      # @return [void]
      #
      # @example Basic invocation
      #   invoke SendEmail::Service do |payload|
      #     { user_id: payload[:user_id], email: payload[:email] }
      #   end
      #
      # @example Async invocation with queue
      #   invoke SendEmail::Service, async: true, queue: :mailers do |payload|
      #     { user_id: payload[:user_id] }
      #   end
      #
      # @example Conditional invocation
      #   invoke GrantRewards::Service, if: ->(p) { p[:premium] } do |payload|
      #     { user_id: payload[:user_id] }
      #   end
      def invoke(service_class, options = {}, &block)
        raise ArgumentError, 'Block required for payload mapping' unless block

        @invocations ||= []
        @invocations << {
          service_class: service_class,
          options: options,
          mapper: block
        }
      end

      # Returns all service invocations declared for this handler.
      #
      # @return [Array<Hash>] array of invocation configurations
      def invocations
        @invocations || []
      end

      # Defines the JSON schema for validating event payloads.
      #
      # @param payload [Hash, nil] JSON schema for validating event payloads
      # @return [void]
      #
      # @example
      #   class UserCreatedHandler < Servus::EventHandler
      #     handles :user_created
      #
      #     schema payload: {
      #       type: 'object',
      #       required: ['user_id', 'email'],
      #       properties: {
      #         user_id: { type: 'integer' },
      #         email: { type: 'string', format: 'email' }
      #       }
      #     }
      #   end
      def schema(payload: nil)
        @payload_schema = payload.with_indifferent_access if payload
      end

      # Returns the payload schema.
      #
      # @return [Hash, nil] the payload schema or nil if not defined
      # @api private
      attr_reader :payload_schema

      # Emits the event this handler is subscribed to.
      #
      # Provides a type-safe, discoverable way to emit events from anywhere in
      # the application (controllers, jobs, rake tasks) without creating a service.
      #
      # @param payload [Hash] the event payload
      # @return [void]
      # @raise [RuntimeError] if no event configured via `handles`
      #
      # @example Emit from controller
      #   class UsersController
      #     def create
      #       user = User.create!(params)
      #       UserCreatedHandler.emit({ user_id: user.id, email: user.email })
      #       redirect_to user
      #     end
      #   end
      #
      # @example Emit from background job
      #   class ProcessDataJob
      #     def perform(data_id)
      #       result = process_data(data_id)
      #       DataProcessedHandler.emit({ data_id: data_id, status: result })
      #     end
      #   end
      def emit(payload)
        raise 'No event configured. Call handles :event_name first.' unless @event_name

        Servus::Support::Validator.validate_event_payload!(self, payload)

        Servus::Events::Bus.emit(@event_name, payload)
      end

      # Handles an event by invoking all configured services.
      #
      # Iterates through all declared invocations, evaluates conditions,
      # maps the payload to service arguments, and invokes each service.
      #
      # @param payload [Hash] the event payload
      # @return [Array<Servus::Support::Response>] results from all invoked services
      #
      # @example
      #   UserCreatedHandler.handle({ user_id: 123, email: 'user@example.com' })
      def handle(payload)
        invocations.map do |invocation|
          next unless should_invoke?(payload, invocation[:options])

          invoke_service(invocation, payload)
        end.compact
      end

      # Validates that all registered handlers subscribe to events that are actually emitted by services.
      #
      # Checks all handlers against all service emissions and raises an error if any
      # handler subscribes to a non-existent event. Helps catch typos and orphaned handlers.
      #
      # Respects the `Servus.config.strict_event_validation` setting - skips validation if false.
      #
      # @return [void]
      # @raise [Servus::Events::OrphanedHandlerError] if a handler subscribes to a non-existent event
      #
      # @example
      #   Servus::EventHandler.validate_all_handlers!
      def validate_all_handlers!
        return unless Servus.config.strict_event_validation

        emitted_events = collect_emitted_events
        orphaned       = find_orphaned_handlers(emitted_events)

        return if orphaned.empty?

        raise Servus::Events::OrphanedHandlerError,
              "Handler(s) subscribe to non-existent events:\n" \
              "#{orphaned.map { |h| "  - #{h[:handler]} subscribes to :#{h[:event]}" }.join("\n")}"
      end

      private

      # Collects all event names that are emitted by services.
      #
      # @return [Set<Symbol>] set of all emitted event names
      # @api private
      def collect_emitted_events
        events = Set.new

        ObjectSpace.each_object(Class)
                   .select { |klass| klass < Servus::Base }
                   .each do |service_class|
          service_class.event_emissions.each_value do |emissions|
            emissions.each { |emission| events << emission[:event_name] }
          end
        end

        events
      end

      # Finds handlers that subscribe to events not emitted by any service.
      #
      # @param emitted_events [Set<Symbol>] set of all emitted event names
      # @return [Array<Hash>] array of orphaned handler info
      # @api private
      def find_orphaned_handlers(emitted_events)
        orphaned = []

        ObjectSpace.each_object(Class)
                   .select { |klass| klass < Servus::EventHandler && klass != Servus::EventHandler }
                   .each do |handler_class|
          next unless handler_class.event_name
          next if emitted_events.include?(handler_class.event_name)

          orphaned << { handler: handler_class.name, event: handler_class.event_name }
        end

        orphaned
      end

      # Invokes a single service with the mapped payload.
      #
      # @param invocation [Hash] the invocation configuration
      # @param payload [Hash] the event payload
      # @return [Servus::Support::Response] the service result
      # @api private
      def invoke_service(invocation, payload)
        service_kwargs = invocation[:mapper].call(payload)

        async = invocation.dig(:options, :async) || false
        queue = invocation.dig(:options, :queue) || nil

        if async
          service_kwargs = service_kwargs.merge(queue: queue) if queue
          invocation[:service_class].call_async(**service_kwargs)
        else
          invocation[:service_class].call(**service_kwargs)
        end
      end

      # Checks if a service should be invoked based on conditions.
      #
      # @param payload [Hash] the event payload
      # @param options [Hash] the invocation options
      # @return [Boolean] true if the service should be invoked
      # @api private
      def should_invoke?(payload, options)
        return false if options[:if] && !options[:if].call(payload)
        return false if options[:unless]&.call(payload)

        true
      end
    end
  end
end
