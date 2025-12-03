# frozen_string_literal: true

module Servus
  module Testing
    # Test helpers for asserting event emissions in RSpec tests.
    #
    # Provides the `servus_expect_event` matcher for testing that services
    # emit events with expected payloads.
    #
    # @example Testing event emission
    #   RSpec.describe CreateUser::Service do
    #     include Servus::Testing::EventHelpers
    #
    #     it 'emits user_created event' do
    #       servus_expect_event(:user_created)
    #         .with_payload(hash_including(user_id: 123))
    #         .when { described_class.call(user_id: 123) }
    #     end
    #   end
    module EventHelpers
      # Creates a matcher for asserting event emission.
      #
      # @param event_name [Symbol] the name of the event to expect
      # @return [EventMatcher] chainable matcher object
      def servus_expect_event(event_name)
        EventMatcher.new(event_name)
      end

      # Custom RSpec matcher for event assertions.
      #
      # @api private
      class EventMatcher
        def initialize(event_name)
          @event_name = event_name
          @expected_payload = nil
        end

        # Specifies the expected payload.
        #
        # @param expected [Object] expected payload (supports RSpec matchers)
        # @return [EventMatcher] self for chaining
        def with_payload(expected)
          @expected_payload = expected
          self
        end

        # Executes block and captures emitted events.
        #
        # @yield block to execute that should emit events
        # @return [void]
        # @raise [RSpec::Expectations::ExpectationNotMetError] if event not emitted or payload doesn't match
        #
        # rubocop:disable Metrics/MethodLength
        def when(&block)
          captured_events = capture_events(&block)

          matching_event = captured_events.find { |e| e[:name] == @event_name }

          unless matching_event
            raise RSpec::Expectations::ExpectationNotMetError,
                  "expected event :#{@event_name} to be emitted, but it was not.\n" \
                  "Emitted events: #{captured_events.map { |e| e[:name] }.inspect}"
          end

          return unless @expected_payload

          return if RSpec::Matchers::BuiltIn::Match.new(@expected_payload).matches?(matching_event[:payload])

          raise RSpec::Expectations::ExpectationNotMetError,
                "expected event :#{@event_name} payload to match #{@expected_payload.inspect}, " \
                "but got #{matching_event[:payload].inspect}"
        end
        # rubocop:enable Metrics/MethodLength

        private

        # Captures all events emitted during block execution.
        #
        # @yield block to execute
        # @return [Array<Hash>] captured events with :name and :payload
        def capture_events
          captured = []
          event_matcher = /^servus\.events\./

          # Subscribe to all servus events
          subscription = ActiveSupport::Notifications.subscribe(event_matcher) do |name, _start, _finish, _id, payload|
            event_name = name.sub('servus.events.', '').to_sym
            captured << { name: event_name, payload: payload }
          end

          yield

          captured
        ensure
          ActiveSupport::Notifications.unsubscribe(subscription) if subscription
        end
      end
    end
  end
end
