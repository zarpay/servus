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
  #     enqueue SendWelcomeEmail::Service do |payload|
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
  #     enqueue AuditLogger::Service
  #   end
  #
  # @see Servus::Events::Bus
  # @see Servus::Events::Router
  # @see Servus::Base
  class Event
    extend Servus::Schema::Declaration

    # @!method self.schema(payload: nil)
    #   Declares the JSON schema for this event's payload.
    #
    #   The payload is validated on every {Servus::Event.emit}. Schemas may
    #   reference shared fragments registered with {Servus::Schema.register};
    #   refs are resolved on first read.
    #
    #   Omitting the keyword leaves any schema declared earlier — or by a
    #   superclass — in place. Passing it explicitly as +nil+ raises.
    #
    #   @param payload [Hash] JSON schema for the event payload
    #   @return [void]
    #   @raise [ArgumentError] on an unknown keyword or an explicit nil
    #
    #   @example
    #     class UserCreated < Servus::Event
    #       event_name :user_created
    #
    #       schema payload: {
    #         type: 'object',
    #         required: ['user_id', 'email'],
    #         properties: {
    #           user_id: { type: 'integer' },
    #           email: { type: 'string', format: 'email' }
    #         }
    #       }
    #     end
    #
    #   @see Servus::Schema
    #
    # @!method self.payload_schema
    #   @return [Hash, nil] the compiled payload schema
    declare_schemas :payload

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

      # Declares a service to enqueue in response to the event.
      #
      # An event can declare as many services as it needs; each is enqueued
      # independently when the event fires. The block maps the event payload to
      # the service's keyword arguments — without one, the full payload is passed
      # through.
      #
      # Invocation is always asynchronous. A reaction that ran inline would put
      # its latency and its failures back into the emitting service, which is
      # what events exist to avoid. This requires ActiveJob; see
      # {Servus::Events::Errors::AsyncBackendMissingError}.
      #
      # @param service_class [Class] the service to enqueue (must inherit from Servus::Base)
      # @param options [Hash] invocation options
      # @option options [Symbol] :queue the queue to route the job to
      # @option options [ActiveSupport::Duration] :wait delay before the job runs
      # @option options [Time] :wait_until absolute time to run the job
      # @option options [Integer] :priority job priority (adapter-dependent)
      # @option options [Hash] :job_options additional ActiveJob options
      # @option options [Proc] :if condition that must return true to enqueue
      # @option options [Proc] :unless condition that must return false to enqueue
      # @yield [payload] block that maps event payload to service arguments
      # @yieldparam payload [Hash] the event payload
      # @yieldreturn [Hash] keyword arguments for the service's initialize method
      # @return [void]
      # @raise [ArgumentError] if the removed +async:+ option is passed
      #
      # @example Enqueue a service
      #   enqueue SendEmail::Service do |payload|
      #     { user_id: payload[:user_id], email: payload[:email] }
      #   end
      #
      # @example Route to a queue
      #   enqueue SendEmail::Service, queue: :mailers do |payload|
      #     { user_id: payload[:user_id] }
      #   end
      #
      # @example Conditional
      #   enqueue GrantRewards::Service, if: ->(p) { p[:premium] } do |payload|
      #     { user_id: payload[:user_id] }
      #   end
      def enqueue(service_class, options = {}, &block)
        reject_async_option!(options)

        @invocations ||= []
        @invocations << {
          service_class: service_class,
          options: options,
          mapper: block || ->(payload) { payload }
        }
      end

      # Explains that +invoke+ was renamed, rather than failing as a typo.
      #
      # Event classes load at boot, so a bare NoMethodError here would read like
      # a misspelling instead of a rename. This covers both changes at once,
      # since the overwhelmingly common declaration was +invoke Foo, async: true+.
      #
      # @raise [NoMethodError] always
      # @deprecated Use {#enqueue}.
      def invoke(*_args, **_options, &)
        raise NoMethodError,
              '`invoke` was renamed to `enqueue` in 1.0.0 — event invocation is always ' \
              'asynchronous. Replace `invoke` with `enqueue`, and drop `async:` if present.'
      end

      # Returns all service invocations declared for this event.
      #
      # @return [Array<Hash>] array of invocation configurations
      def invocations
        @invocations || []
      end

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
        invocations_for(payload).map(&:enqueue)
      end

      private

      # Rejects the removed +async:+ option at declaration time.
      #
      # Declaration time matters here: an Event class loads at boot, so this
      # fails on deploy rather than on the first emit in production. Rejecting
      # +async: false+ is the point — that declaration asks for synchronous
      # invocation, which no longer exists, and quietly giving it the opposite
      # would be worse than refusing.
      #
      # @param options [Hash]
      # @return [void]
      # @raise [ArgumentError] if +:async+ is present, whatever its value
      # @api private
      def reject_async_option!(options)
        return unless options.key?(:async)

        raise ArgumentError,
              '`async:` is no longer a valid option — event invocation is always ' \
              'asynchronous. Remove it from the declaration.'
      end

      # @api private
      def should_invoke?(payload, options)
        return false if options[:if] && !options[:if].call(payload)
        return false if options[:unless]&.call(payload)

        true
      end
    end
  end
end
