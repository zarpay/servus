# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Servus::Events::Router do
  describe '#resolve' do
    it 'raises NotImplementedError' do
      router = described_class.new

      expect { router.resolve(:test_event, {}) }
        .to raise_error(NotImplementedError, /resolve must be implemented/)
    end
  end
end
