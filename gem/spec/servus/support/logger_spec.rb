# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Servus::Support::Logger do
  describe '.default' do
    after { Servus.config.logger = nil }

    it 'is the configured logger' do
      logger = Logger.new(File::NULL)
      Servus.config.logger = logger

      expect(described_class.default).to be(logger)
    end

    it 'falls back to Rails.logger when Rails is loaded' do
      rails_logger = Logger.new(File::NULL)
      stub_const('Rails', Class.new { define_singleton_method(:logger) { rails_logger } })

      expect(described_class.default).to be(rails_logger)
    end

    it 'falls back to a $stdout logger outside Rails' do
      expect(described_class.default).to be_a(Logger)
    end

    it 'picks up a Rails logger assigned after Servus first read one' do
      described_class.default
      rails_logger = Logger.new(File::NULL)
      stub_const('Rails', Class.new { define_singleton_method(:logger) { rails_logger } })

      expect(described_class.default).to be(rails_logger)
    end

    it 'is what Servus.logger returns' do
      expect(Servus.logger).to be(described_class.default)
    end
  end

  describe '#call' do
    let(:messages) { [] }
    let(:service) { stub_const('LoggedService', Class.new(Servus::Base)) }
    let(:log) { described_class.new(service) }

    before { allow(service.logger).to receive(:info) { |msg| messages << msg } }

    it 'logs arguments verbatim by default' do
      log.call({ token: 'ps_supersecret', name: 'ok' })

      expect(messages.last).to include('ps_supersecret')
      expect(messages.last).not_to include('[FILTERED]')
    end

    context 'with log_filter_parameters configured' do
      before { Servus.config.log_filter_parameters = %i[passw token auth] }
      after { Servus.config.log_filter_parameters = [] }

      it 'filters matching argument values' do
        log.call({ token: 'ps_supersecret', name: 'ok' })

        expect(messages.last).to include('[FILTERED]')
        expect(messages.last).to include('"ok"')
        expect(messages.last).not_to include('ps_supersecret')
      end

      it 'filters partial-match keys like raw_token and password' do
        log.call({ raw_token: 'abc', password: 'hunter2' })

        expect(messages.last).not_to include('abc')
        expect(messages.last).not_to include('hunter2')
      end

      it 'filters auth-prefixed keys wholesale, including nested values' do
        log.call({ auth_hash: { credentials: { token: 'ya29.secret' } } })

        expect(messages.last).to include('[FILTERED]')
        expect(messages.last).not_to include('ya29.secret')
      end

      it 'leaves non-matching keys visible' do
        log.call({ wand: 'elder', token: 'hidden' })

        expect(messages.last).to include('elder')
        expect(messages.last).not_to include('hidden')
      end

      it 'applies a reassigned filter list on the next call' do
        log.call({ wand: 'elder' })
        expect(messages.last).to include('elder')

        Servus.config.log_filter_parameters = %i[wand]
        log.call({ wand: 'elder' })

        expect(messages.last).not_to include('elder')
      end
    end

    context 'with arbitrary custom keys configured' do
      before { Servus.config.log_filter_parameters = %i[wand sigil] }
      after { Servus.config.log_filter_parameters = [] }

      it 'masks their values as [FILTERED] while keeping the key names visible' do
        log.call({ wand: 'elder', sigil: 'dark-mark', house: 'gryffindor' })

        expect(messages.last).to match(/wand.*?\[FILTERED\]/)
        expect(messages.last).to match(/sigil.*?\[FILTERED\]/)
        expect(messages.last).not_to include('elder')
        expect(messages.last).not_to include('dark-mark')
        expect(messages.last).to include('gryffindor')
      end
    end
  end
end
