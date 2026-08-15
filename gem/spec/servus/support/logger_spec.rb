# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Servus::Support::Logger do
  describe '.log_call' do
    let(:messages) { [] }

    before { allow(described_class.logger).to receive(:info) { |msg| messages << msg } }

    it 'logs arguments verbatim by default' do
      described_class.log_call(String, { token: 'ps_supersecret', name: 'ok' })

      expect(messages.last).to include('ps_supersecret')
      expect(messages.last).not_to include('[FILTERED]')
    end

    context 'with log_filter_parameters configured' do
      before { Servus.config.log_filter_parameters = %i[passw token auth] }
      after { Servus.config.log_filter_parameters = [] }

      it 'filters matching argument values' do
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

      it 'leaves non-matching keys visible' do
        described_class.log_call(String, { wand: 'elder', token: 'hidden' })

        expect(messages.last).to include('elder')
        expect(messages.last).not_to include('hidden')
      end

      it 'picks up in-place mutations of the filter list' do
        described_class.log_call(String, { wand: 'elder' })
        expect(messages.last).to include('elder')

        Servus.config.log_filter_parameters << :wand
        described_class.log_call(String, { wand: 'elder' })

        expect(messages.last).not_to include('elder')
      end
    end

    context 'with arbitrary custom keys configured' do
      before { Servus.config.log_filter_parameters = %i[wand sigil] }
      after { Servus.config.log_filter_parameters = [] }

      it 'masks their values as [FILTERED] while keeping the key names visible' do
        described_class.log_call(String, { wand: 'elder', sigil: 'dark-mark', house: 'gryffindor' })

        expect(messages.last).to match(/wand.*?\[FILTERED\]/)
        expect(messages.last).to match(/sigil.*?\[FILTERED\]/)
        expect(messages.last).not_to include('elder')
        expect(messages.last).not_to include('dark-mark')
        expect(messages.last).to include('gryffindor')
      end
    end
  end
end
