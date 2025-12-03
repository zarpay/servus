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
end
