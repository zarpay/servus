# frozen_string_literal: true

module Servus
  # Base class for event definitions.
  #
  # Event classes live in app/events/ and serve three purposes:
  #
  # 1. *Contract* — declares the event exists and defines its name
  # 2. *Validator* — schema enforcement on any emission
  # 3. *Declarative routing* — optional +invoke+ declarations
  #
  # The event name can be set explicitly via +event_name+ or inferred
  # from the class name (e.g. +OrderPlaced+ becomes +:order_placed+).
  # Call +ensure_registered!+ to trigger inference for classes that
  # don't declare an explicit name.
  #
  # @example Event with explicit name and invoke declarations
  #   class UserCreated < Servus::Event
  #     event_name :user_created
  #
  #     schema payload: { type: 'object', required: ['user_id'] }
  #
  #     invoke SendWelcomeEmail::Service, async: true do |payload|
  #       { user_id: payload[:user_id] }
  #     end
  #   end
  #
  # @example Event with inferred name (no invoke — schema-only contract)
  #   class OrderPlaced < Servus::Event
  #     schema payload: { type: 'object', required: ['order_id'] }
  #   end
  #
  # @example Event that passes full payload through (no mapper block)
  #   class AuditLogCreated < Servus::Event
  #     event_name :audit_log_created
  #
  #     invoke AuditLogger::Service, async: true
  #   end
  #
  # @see Servus::Events::Bus
  # @see Servus::Events::Router
  # @see Servus::Base
  class Event
    class << self
      # Declares or returns the event name.
      #
      # When called with an argument, sets the event name and registers
      # with the Bus. When called without arguments, returns the current
      # event name.
      #
      # If never called explicitly, use +ensure_registered!+ to infer
      # the name from the class name.
      #
      # @overload event_name(name)
      #   @param name [Symbol] the event name to register
      #   @return [void]
      #   @raise [RuntimeError] if called twice with different names
      #
      # @overload event_name
      #   @return [Symbol, nil] the event name or nil if not configured
      #
      # @example Explicit name
      #   class UserCreated < Servus::Event
      #     event_name :user_created
      #   end
      #
      # @example Inferred name (via ensure_registered!)
      #   class OrderPlaced < Servus::Event; end
      #   OrderPlaced.ensure_registered!
      #   OrderPlaced.event_name # => :order_placed
      def event_name(name = nil)
        return @event_name if name.nil?

        raise "Event already subscribed to :#{@event_name}. Cannot subscribe to :#{name}" if @event_name

        @event_name = name
        Servus::Events::Bus.register_event(name, self)
      end

      # Infers and registers the event name from the class name if not
      # already set explicitly. Safe to call multiple times — does
      # nothing if already registered. Skips anonymous classes.
      #
      # @return [void]
      def ensure_registered!
        return if @event_name
        return if name.nil?

        event_name(name.demodulize.underscore.to_sym)
      end

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
        @invocations ||= []
        @invocations << {
          service_class: service_class,
          options: options,
          mapper: block || ->(payload) { payload }
        }
      end

      # Returns all service invocations declared for this event.
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
      #   class UserCreated < Servus::Event
      #     event_name :user_created
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

      # Emits this event via the Bus.
      #
      # Provides a type-safe, discoverable way to emit events from anywhere in
      # the application (controllers, jobs, rake tasks) without creating a service.
      #
      # @param payload [Hash] the event payload
      # @return [void]
      # @raise [RuntimeError] if no event name configured
      #
      # @example Emit from controller
      #   class UsersController
      #     def create
      #       user = User.create!(params)
      #       UserCreated.emit({ user_id: user.id, email: user.email })
      #       redirect_to user
      #     end
      #   end
      #
      # @example Emit from background job
      #   class ProcessDataJob
      #     def perform(data_id)
      #       result = process_data(data_id)
      #       DataProcessed.emit({ data_id: data_id, status: result })
      #     end
      #   end
      def emit(payload)
        raise 'No event configured. Call event_name :name first.' unless @event_name

        Servus::Support::Validator.validate_event_payload!(self, payload)

        Servus::Events::Bus.emit(@event_name, payload)
      end

      # Returns Invocation objects for the given payload, with conditions
      # already evaluated. This is what routers call to resolve actions.
      #
      # @param payload [Hash] the event payload
      # @return [Array<Servus::Events::Invocation>] invocations that passed conditions
      def invocations_for(payload)
        invocations.filter_map do |inv|
          next unless should_invoke?(payload, inv[:options])

          Servus::Events::Invocation.new(
            service: inv[:service_class],
            params: inv[:mapper].call(payload),
            options: inv[:options].except(:if, :unless)
          )
        end
      end

      # Handles an event by resolving and executing all invocations.
      #
      # @param payload [Hash] the event payload
      # @return [Array] results from all invoked services
      def handle(payload)
        invocations_for(payload).map(&:execute)
      end

      private

      # @api private
      def should_invoke?(payload, options)
        return false if options[:if] && !options[:if].call(payload)
        return false if options[:unless]&.call(payload)

        true
      end
    end
  end
end
