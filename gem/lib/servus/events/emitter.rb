# frozen_string_literal: true

module Servus
  module Events
    # Provides event emission DSL for service objects.
    #
    # This module adds the `emits` class method to services, allowing them to
    # declare events that will be automatically emitted on success, failure, or error.
    #
    # @example Basic usage
    #   class CreateUser < Servus::Base
    #     emits :user_created, on: :success
    #     emits :user_failed, on: :failure
    #   end
    module Emitter
      extend ActiveSupport::Concern

      # Triggers accepted by the +emits+ DSL.
      #
      # +:success+ and +:failure+ are selected from the service's result after
      # +call+ returns. +:error!+ is fired by {Servus::Base#error!} immediately
      # before it raises, so it never coincides with +:failure+.
      #
      # Note the bang on +:error!+ — it mirrors the method that triggers it.
      EMISSION_TRIGGERS = %i[success failure error!].freeze

      # Emits events for a service result.
      #
      # Called automatically after service execution completes. Determines the
      # trigger type based on the result and emits all configured events.
      #
      # @param instance [Servus::Base] the service instance
      # @param result [Servus::Support::Response] the service result
      # @return [void]
      # @api private
      def self.emit_result_events!(instance, result)
        trigger = result.success? ? :success : :failure
        instance.send(:emit_events_for, trigger, result)
      end

      class_methods do
        # Declares an event that this service will emit.
        #
        # Events are automatically emitted when the service completes with the specified
        # trigger condition (:success, :failure, or :error!). Use the `with` option or a
        # block to provide a custom payload builder. Use `if` or `unless` to gate emission
        # on a runtime condition.
        #
        # @param event_name [Symbol] the name of the event to emit
        # @param on [Symbol] when to emit (:success, :failure, or :error!)
        # @option options [Symbol, nil] :with instance method name for building the payload
        # @option options [Proc, Symbol, nil] :if condition proc or method name; event only emits when truthy
        # @option options [Proc, Symbol, nil] :unless condition proc or method name; event only emits when falsy
        # @yield [result] optional block for building the payload
        # @yieldparam result [Servus::Support::Response] the service result
        # @yieldreturn [Hash] the event payload
        # @return [void]
        #
        # @example Emit on success with default payload
        #   class CreateUser < Servus::Base
        #     emits :user_created, on: :success
        #   end
        #
        # @example Emit with custom payload builder method
        #   class CreateUser < Servus::Base
        #     emits :user_created, on: :success, with: :user_payload
        #
        #     private
        #
        #     def user_payload(result)
        #       { user_id: result.data[:user].id }
        #     end
        #   end
        #
        # @example Emit with custom payload builder block
        #   class CreateUser < Servus::Base
        #     emits :user_created, on: :success do |result|
        #       { user_id: result.data[:user].id }
        #     end
        #   end
        #
        # @example Conditional emission with if: lambda
        #   class CreateUser < Servus::Base
        #     emits :premium_user_created, on: :success, if: ->(result) { result.data[:plan] == :premium }
        #   end
        #
        # @example Conditional emission with unless: method reference
        #   class CreateUser < Servus::Base
        #     emits :user_created, on: :success, unless: :suppressed?
        #
        #     private
        #
        #     def suppressed?(result)
        #       result.data[:suppressed]
        #     end
        #   end
        #
        # @example Multiple events on one trigger, each with its own payload
        #   class CreateUser < Servus::Base
        #     emits :user_created, on: :success
        #     emits :welcome_queued, on: :success, with: :welcome_payload
        #   end
        #
        # @see Servus::Events::Bus
        # @see Servus::Event
        def emits(event_name, on:, **options, &block)
          unless EMISSION_TRIGGERS.include?(on)
            raise ArgumentError,
                  "Invalid trigger: #{on}. Must be one of: #{EMISSION_TRIGGERS.join(', ')}"
          end

          @event_emissions ||= empty_emissions
          @event_emissions[on] << build_emission(event_name, options, block)
        end

        # Returns all event emissions declared for this service.
        #
        # @return [Hash] hash of event emissions grouped by trigger
        #   { success: [...], failure: [...], error!: [...] }
        def event_emissions = @event_emissions || empty_emissions

        # Returns event emissions for a specific trigger.
        #
        # @param trigger [Symbol] the trigger type (:success, :failure, :error!)
        # @return [Array<Hash>] array of event configurations for this trigger
        def emissions_for(trigger) = event_emissions[trigger] || []

        private

        # An empty emission set, one entry per supported trigger.
        #
        # Derived from {Emitter::EMISSION_TRIGGERS} rather than written out, so
        # the shape cannot drift from the list of triggers actually accepted.
        #
        # @return [Hash{Symbol => Array}]
        # @api private
        def empty_emissions = EMISSION_TRIGGERS.to_h { |trigger| [trigger, []] }

        def build_emission(event_name, options, block)
          {
            event_name: event_name,
            if_condition: options[:if],
            unless_condition: options[:unless],
            payload_builder: block || options[:with]
          }
        end
      end

      # Emits events for a specific trigger with the given result.
      #
      # @param trigger [Symbol] the trigger type (:success, :failure, :error!)
      # @param result [Servus::Support::Response] the service result
      # @return [void]
      # @api private
      def emit_events_for(trigger, result)
        self.class.emissions_for(trigger).each do |emission|
          next unless emission_condition_met?(emission, result)

          payload = build_event_payload(emission, result)
          validate_event_payload!(emission[:event_name], payload)
          Servus::Events::Bus.emit(emission[:event_name], payload)
        end
      end

      # Instance methods for emitting events during service execution

      # Returns true when all declared conditions on the emission pass.
      #
      # @param emission [Hash] the emission configuration
      # @param result [Servus::Support::Response] the service result
      # @return [Boolean]
      # @api private
      def emission_condition_met?(emission, result)
        if_condition = emission[:if_condition]
        unless_condition = emission[:unless_condition]

        return false if if_condition && !evaluate_emission_condition(if_condition, result)
        return false if unless_condition && evaluate_emission_condition(unless_condition, result)

        true
      end

      # Evaluates a single emission condition — either a Proc/lambda or a Symbol method reference.
      #
      # Both forms receive the result object so conditions can inspect result.data,
      # result.error, result.success?, etc.
      #
      # @param condition [Proc, Symbol] the condition to evaluate
      # @param result [Servus::Support::Response] the service result
      # @return [Object] truthy or falsy value
      # @api private
      def evaluate_emission_condition(condition, result)
        condition.is_a?(Proc) ? instance_exec(result, &condition) : send(condition, result)
      end

      # Validates the payload against the Event class's schema registered for the event.
      #
      # @param event_name [Symbol] the event name
      # @param payload [Hash] the event payload
      # @return [void]
      # @raise [Servus::Support::Errors::ValidationError] if payload fails validation
      # @api private
      def validate_event_payload!(event_name, payload)
        event_class = Servus::Events::Bus.event_for(event_name)
        return require_event_schema!(event_name) unless event_class

        Servus::Support::Validator.validate_event_payload!(event_class, payload)
      end

      # Enforces {Servus::Config#require_event_payload_schema} for an event that
      # has no Event class to carry a schema.
      #
      # An unregistered event name is the one case where a payload cannot be
      # validated at all, so it is exactly where the flag matters most. Skipping
      # it here would mean the setting silently passed over the events furthest
      # from having a contract.
      #
      # @param event_name [Symbol] the event being emitted
      # @return [void]
      # @raise [Servus::Support::Errors::SchemaRequiredError] if enforcement is enabled
      # @api private
      def require_event_schema!(event_name)
        return unless Servus.config.require_event_payload_schema

        raise Servus::Support::Errors::SchemaRequiredError,
              "#{self.class} emits :#{event_name} but no Event class is registered for it — " \
              'schema missing! require_event_payload_schema is set to true.'
      end

      # Builds the event payload using the configured payload builder or defaults.
      #
      # @param emission [Hash] the emission configuration
      # @param result [Servus::Support::Response] the service result
      # @return [Hash] the event payload
      # @api private
      def build_event_payload(emission, result)
        builder = emission[:payload_builder]

        if builder.is_a?(Proc)
          instance_exec(result, &builder)
        elsif builder.is_a?(Symbol)
          # Method-based payload builder
          send(builder, result)
        elsif result.success?
          # Default for success: return data
          result.data
        else
          # Default for failure/error: return error
          result.error
        end
      end
    end
  end
end
