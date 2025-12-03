# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
require 'rspec/expectations'

module Servus
  module Testing
    # RSpec matchers for testing Servus services and events.
    module Matchers
    end
  end
end

# Matcher for asserting event emission
RSpec::Matchers.define :emit_event do |handler_class_or_symbol|
  supports_block_expectations

  chain :with do |payload|
    @expected_payload = payload
  end

  match do |block|
    @captured_events = []

    subscription = ActiveSupport::Notifications.subscribe(/^servus\.events\./) do |name, *_args, payload|
      event_name = name.sub('servus.events.', '').to_sym
      @captured_events << { name: event_name, payload: payload }
    end

    block.call

    # Determine event name
    @event_name = if handler_class_or_symbol.is_a?(Symbol)
                    handler_class_or_symbol
                  else
                    handler_class_or_symbol.event_name
                  end

    @matching_event = @captured_events.find { |e| e[:name] == @event_name }

    return false unless @matching_event
    return true unless @expected_payload

    RSpec::Matchers::BuiltIn::Match.new(@expected_payload).matches?(@matching_event[:payload])
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription) if subscription
  end

  failure_message do
    if @matching_event.nil?
      "expected event :#{@event_name} to be emitted, but it was not.\n" \
      "Emitted: #{@captured_events.map { |e| e[:name] }}"
    else
      "expected event :#{@event_name} payload to match #{@expected_payload.inspect}, " \
      "got: #{@matching_event[:payload].inspect}"
    end
  end
end

# Matcher for asserting service invocation
RSpec::Matchers.define :call_service do |service_class|
  supports_block_expectations

  chain :with do |args|
    @expected_args = args
  end

  chain :async do
    @expect_async = true
  end

  match do |block|
    method_name = @expect_async ? :call_async : :call

    expectation = expect(service_class).to receive(method_name)
    expectation.with(@expected_args) if @expected_args

    block.call

    true
  end

  failure_message do
    method = @expect_async ? 'call_async' : 'call'
    "expected #{service_class} to receive #{method}"
  end
end
# rubocop:enable Metrics/BlockLength
