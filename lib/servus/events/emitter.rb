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
        # trigger condition (:success, :failure, or :error). Use the `with` option to
        # provide a custom payload builder, or pass a block.
        #
        # @param event_name [Symbol] the name of the event to emit
        # @param on [Symbol] when to emit (:success, :failure, or :error)
        # @param with [Symbol, nil] optional instance method name for building the payload
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
        # @note Best Practice: Services should typically emit ONE event per trigger
        #   that represents their core concern. Multiple downstream reactions should
        #   be coordinated by EventHandler classes, not by emitting multiple events
        #   from the service. This maintains separation of concerns.
        #
        # @example Recommended pattern (one event, multiple handlers)
        #   # Service emits one event
        #   class CreateUser < Servus::Base
        #     emits :user_created, on: :success
        #   end
        #
        #   # Handler coordinates multiple reactions
        #   class UserCreatedHandler < Servus::EventHandler
        #     handles :user_created
        #     invoke SendWelcomeEmail::Service, async: true
        #     invoke TrackAnalytics::Service, async: true
        #   end
        #
        # @see Servus::Events::Bus
        # @see Servus::EventHandler
        def emits(event_name, on:, with: nil, &block)
          valid_triggers = %i[success failure error!]

          unless valid_triggers.include?(on)
            raise ArgumentError, "Invalid trigger: #{on}. Must be one of: #{valid_triggers.join(', ')}"
          end

          @event_emissions ||= { success: [], failure: [], error!: [] }
          @event_emissions[on] << {
            event_name: event_name,
            payload_builder: block || with
          }
        end

        # Returns all event emissions declared for this service.
        #
        # @return [Hash] hash of event emissions grouped by trigger
        #   { success: [...], failure: [...], error!: [...] }
        def event_emissions
          @event_emissions || { success: [], failure: [], error!: [] }
        end

        # Returns event emissions for a specific trigger.
        #
        # @param trigger [Symbol] the trigger type (:success, :failure, :error!)
        # @return [Array<Hash>] array of event configurations for this trigger
        def emissions_for(trigger)
          event_emissions[trigger] || []
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
          payload = build_event_payload(emission, result)
          Servus::Events::Bus.emit(emission[:event_name], payload)
        end
      end

      # Instance methods for emitting events during service execution
      private

      # Builds the event payload using the configured payload builder or defaults.
      #
      # @param emission [Hash] the emission configuration
      # @param result [Servus::Support::Response] the service result
      # @return [Hash] the event payload
      # @api private
      def build_event_payload(emission, result)
        builder = emission[:payload_builder]

        if builder.is_a?(Proc)
          # Block-based payload builder
          builder.call(result)
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
