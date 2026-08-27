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
RSpec::Matchers.define :emit_event do |event_class_or_symbol|
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
    @event_name = if event_class_or_symbol.is_a?(Symbol)
                    event_class_or_symbol
                  else
                    event_class_or_symbol.event_name
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

  failure_message_when_negated do
    "expected event :#{@event_name} not to be emitted, but it was.\n" \
      "Payload: #{@matching_event[:payload].inspect}"
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

# Matcher for asserting schema presence on a service or Event class
RSpec::Matchers.define :have_schema do |schema_type|
  match do |klass|
    !Servus::Support::Validator.load_schema(klass, schema_type.to_s).nil?
  end

  failure_message do |klass|
    "expected #{klass.name} to have a #{schema_type} schema defined"
  end

  failure_message_when_negated do |klass|
    "expected #{klass.name} not to have a #{schema_type} schema defined"
  end
end

# Matcher for asserting a successful service response
RSpec::Matchers.define :be_service_success do
  match do |result|
    @result = result
    result.is_a?(Servus::Support::Response) && result.success?
  end

  failure_message do
    if @result.is_a?(Servus::Support::Response)
      "expected a successful response, but got failure with error: #{@result.error&.message}"
    else
      "expected a Servus::Support::Response, got #{@result.class}"
    end
  end

  failure_message_when_negated do
    'expected a failure response, but got success'
  end
end

# Matcher for asserting a failed service response with optional error class and message
RSpec::Matchers.define :be_service_failure do |expected_error_class|
  chain :with_message do |message|
    @expected_message = message
  end

  match do |result|
    @result = result
    return false unless result.is_a?(Servus::Support::Response) && result.failure?
    return false if expected_error_class && !result.error.is_a?(expected_error_class)
    return false if @expected_message && result.error.message != @expected_message

    true
  end

  failure_message do
    if !@result.is_a?(Servus::Support::Response)
      "expected a Servus::Support::Response, got #{@result.class}"
    elsif @result.success?
      'expected a failure response, but got success'
    elsif expected_error_class && !@result.error.is_a?(expected_error_class)
      "expected error to be a #{expected_error_class.name}, got #{@result.error.class.name}"
    elsif @expected_message
      "expected error message #{@expected_message.inspect}, got #{@result.error.message.inspect}"
    end
  end
end

# Matcher for asserting a guard failure response with optional error code and message
RSpec::Matchers.define :be_guard_failure do |expected_code|
  chain :with_message do |message|
    @expected_message = message
  end

  match do |result|
    @result = result
    return false unless result.is_a?(Servus::Support::Response) && result.failure?
    return false unless result.error.is_a?(Servus::Support::Errors::GuardError)
    return false if expected_code && result.error.code != expected_code
    return false if @expected_message && result.error.message != @expected_message

    true
  end

  failure_message do
    if !@result.is_a?(Servus::Support::Response)
      "expected a Servus::Support::Response, got #{@result.class}"
    elsif @result.success?
      'expected a guard failure response, but got success'
    elsif !@result.error.is_a?(Servus::Support::Errors::GuardError)
      "expected error to be a GuardError, got #{@result.error.class.name}"
    elsif expected_code && @result.error.code != expected_code
      "expected guard error code #{expected_code.inspect}, got #{@result.error.code.inspect}"
    elsif @expected_message
      "expected guard error message #{@expected_message.inspect}, got #{@result.error.message.inspect}"
    end
  end
end
# rubocop:enable Metrics/BlockLength
