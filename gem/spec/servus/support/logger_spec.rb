# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Servus::Support::Logger do
  let(:logger) { instance_spy(Logger) }
  let(:service) { stub_const('LoggedService', Class.new(Servus::Base)) }
  let(:log) { described_class.new(service) }

  before { service.logger = logger }

  describe '.default' do
    after { Servus.config.logger = nil }

    it 'is the configured logger' do
      configured = Logger.new(File::NULL)
      Servus.config.logger = configured

      expect(described_class.default).to be(configured)
    end

    it 'falls back to Rails.logger when Rails is loaded' do
      rails_logger = Logger.new(File::NULL)
      stub_const('Rails', Class.new { define_singleton_method(:logger) { rails_logger } })

      expect(described_class.default).to be(rails_logger)
    end

    it 'falls back to a $stdout logger outside Rails' do
      expect(described_class.default).to be_a(Logger)
    end

    it 'picks up a Rails logger set after Servus first read one' do
      described_class.default
      rails_logger = Logger.new(File::NULL)
      stub_const('Rails', Class.new { define_singleton_method(:logger) { rails_logger } })

      expect(described_class.default).to be(rails_logger)
    end
  end

  describe 'the lines that name no service' do
    before { Servus.config.logger = logger }
    after  { Servus.config.logger = nil }

    it 'logs an event with its correlation id and duration' do
      described_class.event(:gold_transferred, { amount: 50 }, event_id: 'abc123', duration_ms: 1.25)

      expect(logger).to have_received(:info)
        .with(a_string_starting_with('[abc123] Event :gold_transferred (1.3ms)'))
    end

    it 'logs a schema fragment override' do
      described_class.schema_override('core')

      expect(logger).to have_received(:warn)
        .with('Schema fragment "core" was already registered with a different value; replacing it.')
    end
  end

  it 'logs the call with its arguments' do
    log.call({ amount: 1 })

    expect(logger).to have_received(:info).with(a_string_starting_with('Calling LoggedService with args:'))
  end

  it 'logs a success with its duration' do
    log.success(0.0125)

    expect(logger).to have_received(:info).with('LoggedService succeeded in 0.013s')
  end

  it 'logs a failure with its error and duration' do
    log.failure('nope', 0.0125)

    expect(logger).to have_received(:warn).with('LoggedService failed in 0.013s with error: nope')
  end

  it 'logs a guard failure' do
    log.guard_failure(Servus::Support::Errors::GuardError.new('not allowed'))

    expect(logger).to have_received(:warn).with('LoggedService guard failed: not allowed')
  end

  it 'logs a validation error' do
    log.validation_error(Servus::Support::Errors::ValidationError.new('bad input'))

    expect(logger).to have_received(:error).with('LoggedService validation error: bad input')
  end

  it 'logs an uncaught exception' do
    log.exception(ArgumentError.new('boom'))

    expect(logger).to have_received(:error).with('LoggedService uncaught exception: ArgumentError - boom')
  end

  describe 'argument filtering' do
    after { Servus.config.log_filter_parameters = [] }

    it 'logs arguments verbatim by default' do
      log.call({ token: 'supersecret' })

      expect(logger).to have_received(:info).with(/supersecret/)
    end

    it 'masks configured keys' do
      Servus.config.log_filter_parameters = %i[token]

      log.call({ token: 'supersecret', name: 'ok' })

      expect(logger).to have_received(:info).with(a_string_including('[FILTERED]', 'ok'))
      expect(logger).not_to have_received(:info).with(/supersecret/)
    end
  end
end
