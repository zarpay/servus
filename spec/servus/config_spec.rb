# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Servus::Config do
  describe '.config' do
    it 'has strict_event_validation enabled by default' do
      expect(Servus.config.strict_event_validation).to be true
    end

    it 'allows disabling strict_event_validation' do
      Servus.config.strict_event_validation = false
      expect(Servus.config.strict_event_validation).to be false

      # Reset for other tests
      Servus.config.strict_event_validation = true
    end
  end

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
end
