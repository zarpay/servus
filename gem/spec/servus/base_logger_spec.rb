# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Servus::Base, '.logger' do
  let(:engine_logger) { instance_spy(Logger) }
  let(:host_logger) { instance_spy(Logger) }

  after { described_class.logger = nil }

  it 'defaults to the configured logger' do
    expect(described_class.logger).to be(Servus.logger)
  end

  it 'covers the services below the class it is assigned to' do
    base = stub_const('EngineBaseService', Class.new(described_class))
    child = stub_const('EngineChildService', Class.new(base))

    base.logger = engine_logger

    expect(child.logger).to be(engine_logger)
  end

  it 'leaves the classes beside it alone' do
    stub_const('OwnLoggerService', Class.new(described_class)).logger = engine_logger
    sibling = stub_const('SiblingService', Class.new(described_class))

    expect(sibling.logger).to be(Servus.logger)
  end

  it 'returns to the inherited logger when assigned nil' do
    klass = stub_const('ResetService', Class.new(described_class))
    klass.logger = engine_logger
    klass.logger = nil

    expect(klass.logger).to be(Servus.logger)
  end

  describe 'in a call chain' do
    before { described_class.logger = host_logger }

    it 'writes each service through its own logger' do
      stub_const('MixedEngineService', Class.new(described_class) do
        def call = success({})
      end).logger = engine_logger

      stub_const('MixedHostService', Class.new(described_class) do
        def call
          MixedEngineService.call
          success({})
        end
      end).call

      expect(engine_logger).to have_received(:info).with(/MixedEngineService/).twice
      expect(host_logger).to have_received(:info).with(/MixedHostService/).twice
    end

    it 'writes through its own logger when called from a spawned thread' do
      stub_const('ThreadedEngineService', Class.new(described_class) do
        def call = success({})
      end).logger = engine_logger

      stub_const('ThreadedHostService', Class.new(described_class) do
        def call
          Thread.new { ThreadedEngineService.call }.join
          success({})
        end
      end).call

      expect(engine_logger).to have_received(:info).with(/ThreadedEngineService/).twice
      expect(host_logger).to have_received(:info).with(/ThreadedHostService/).twice
    end
  end
end
