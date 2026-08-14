# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Servus::Support::Logger do
  describe '.log_call' do
    let(:messages) { [] }

    before { allow(described_class.logger).to receive(:info) { |msg| messages << msg } }

    it 'filters credential-shaped argument values' do
      described_class.log_call(String, { token: 'ps_supersecret', name: 'ok' })

      expect(messages.last).to include('[FILTERED]')
      expect(messages.last).to include('"ok"')
      expect(messages.last).not_to include('ps_supersecret')
    end

    it 'filters partial-match keys like raw_token and password' do
      described_class.log_call(String, { raw_token: 'abc', password: 'hunter2' })

      expect(messages.last).not_to include('abc')
      expect(messages.last).not_to include('hunter2')
    end

    it 'filters auth-prefixed keys wholesale, including nested values' do
      described_class.log_call(String, { auth_hash: { credentials: { token: 'ya29.secret' } } })

      expect(messages.last).to include('[FILTERED]')
      expect(messages.last).not_to include('ya29.secret')
    end

    it 'picks up in-place mutations of the filter list' do
      described_class.log_call(String, { wand: 'elder' })
      expect(messages.last).to include('elder')

      Servus.config.log_filter_parameters << :wand
      described_class.log_call(String, { wand: 'elder' })

      expect(messages.last).not_to include('elder')
    ensure
      Servus.config.log_filter_parameters = Servus::Config::DEFAULT_LOG_FILTER_PARAMETERS.dup
    end

    it 'respects a customized filter list' do
      Servus.config.log_filter_parameters = %i[wand]
      described_class.log_call(String, { wand: 'elder', token: 'visible-now' })

      expect(messages.last).not_to include('elder')
      expect(messages.last).to include('visible-now')
    ensure
      Servus.config.log_filter_parameters = Servus::Config::DEFAULT_LOG_FILTER_PARAMETERS.dup
    end
  end
end
