# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Servus::Config do
  describe '#guards_dir' do
    let(:default_dir) { 'app/guards' }

    it 'defaults to app/guards' do
      expect(Servus.config.guards_dir).to eq(default_dir)
    end

    it 'can be customized' do
      Servus.config.guards_dir = 'lib/guards'
      expect(Servus.config.guards_dir).to eq('lib/guards')
    end

    after { Servus.config.guards_dir = default_dir }
  end

  describe '#tests_dir' do
    let(:default_dir) { 'spec' }

    it 'defaults to spec' do
      expect(Servus.config.tests_dir).to eq(default_dir)
    end

    it 'can be customized' do
      Servus.config.tests_dir = 'test'
      expect(Servus.config.tests_dir).to eq('test')
    end

    after { Servus.config.tests_dir = default_dir }
  end

  describe '#include_default_guards' do
    let(:default_value) { true }

    it 'defaults to true' do
      expect(Servus.config.include_default_guards).to be(default_value)
    end

    it 'can be disabled' do
      Servus.config.include_default_guards = false
      expect(Servus.config.include_default_guards).to be false
    end

    after { Servus.config.include_default_guards = default_value }
  end

  describe '#require_service_arguments_schema' do
    it 'defaults to false' do
      expect(Servus.config.require_service_arguments_schema).to be false
    end

    it 'can be enabled' do
      Servus.config.require_service_arguments_schema = true
      expect(Servus.config.require_service_arguments_schema).to be true
    end

    after { Servus.config.require_service_arguments_schema = false }
  end

  describe '#require_service_result_schema' do
    it 'defaults to false' do
      expect(Servus.config.require_service_result_schema).to be false
    end

    it 'can be enabled' do
      Servus.config.require_service_result_schema = true
      expect(Servus.config.require_service_result_schema).to be true
    end

    after { Servus.config.require_service_result_schema = false }
  end

  describe '#require_event_payload_schema' do
    it 'defaults to false' do
      expect(Servus.config.require_event_payload_schema).to be false
    end

    it 'can be enabled' do
      Servus.config.require_event_payload_schema = true
      expect(Servus.config.require_event_payload_schema).to be true
    end

    after { Servus.config.require_event_payload_schema = false }
  end

  describe '#log_filter_parameters' do
    after { Servus.config.log_filter_parameters = [] }

    it 'defaults to an empty list' do
      expect(Servus.config.log_filter_parameters).to eq([])
    end

    it 'can be customized' do
      Servus.config.log_filter_parameters = %i[token]
      expect(Servus.config.log_filter_parameters).to eq(%i[token])
    end

    it 'freezes the assigned list so it cannot be mutated in place' do
      Servus.config.log_filter_parameters = %i[token]
      expect { Servus.config.log_filter_parameters << :wand }.to raise_error(FrozenError)
    end

    it 'rebuilds the memoized parameter filter on reassignment' do
      Servus.config.log_filter_parameters = %i[token]
      stale_filter = Servus.config.parameter_filter

      Servus.config.log_filter_parameters = %i[wand]

      expect(Servus.config.parameter_filter).not_to be(stale_filter)
      expect(Servus.config.parameter_filter.filter({ wand: 'elder' })).to eq({ wand: '[FILTERED]' })
    end
  end

  describe '#lockdown_enabled' do
    after { Servus.config.lockdown_enabled = false }

    it 'toggles the public/private visibility of Servus::Base.new' do
      Servus.config.lockdown_enabled = true
      expect(Servus::Base.singleton_class.private_method_defined?(:new)).to be true

      Servus.config.lockdown_enabled = false
      expect(Servus::Base.singleton_class.public_method_defined?(:new)).to be true
    end

    it 'can be re-enabled after being disabled' do
      Servus.config.lockdown_enabled = false
      Servus.config.lockdown_enabled = true
      expect(Servus.config.lockdown_enabled).to be true
    end
  end
end
