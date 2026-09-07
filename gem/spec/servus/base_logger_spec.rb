# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Servus::Base, 'Logger' do
  let(:collector_class) do
    Class.new do
      attr_reader :messages

      def initialize
        @messages = []
      end

      %i[info warn error].each do |level|
        define_method(level) { |message| @messages << "#{level.to_s.upcase} #{message}" }
      end
    end
  end

  let(:default_logger) { collector_class.new }
  let(:engine_logger) { collector_class.new }

  around do |example|
    described_class.logger = default_logger
    example.run
  ensure
    described_class.logger = nil
  end

  def service(name, logger: nil, &body)
    stub_const(name, Class.new(described_class) do
      self.logger = logger if logger

      def initialize(**); end

      define_method(:call, &body)
    end)
  end

  describe '.logger' do
    it 'is inherited by a service that does not assign one' do
      klass = service('InheritingService') { success({}) }

      expect(klass.logger).to be(default_logger)
    end

    it 'covers the services below the class it is assigned to' do
      logger = engine_logger
      base = stub_const('EngineBaseService', Class.new(described_class) { self.logger = logger })
      child = stub_const('EngineChildService', Class.new(base))

      expect(child.logger).to be(engine_logger)
    end

    it 'changes nothing above or beside the class it is assigned to' do
      service('OwnLoggerService', logger: engine_logger) { success({}) }
      sibling = service('SiblingService') { success({}) }

      expect(described_class.logger).to be(default_logger)
      expect(sibling.logger).to be(default_logger)
    end

    it 'returns to the inherited logger when assigned nil' do
      klass = service('ResetService', logger: engine_logger) { success({}) }

      klass.logger = nil

      expect(klass.logger).to be(default_logger)
    end

    it 'follows a reassignment on the class above it' do
      base = stub_const('ReassignedBaseService', Class.new(described_class))
      child = stub_const('ReassignedChildService', Class.new(base))

      base.logger = engine_logger

      expect(child.logger).to be(engine_logger)
    end

    it 'is what a service body reads from `logger`' do
      seen = nil
      klass = service('InstanceReaderService', logger: engine_logger) do
        seen = logger
        success({})
      end

      klass.call

      expect(seen).to be(engine_logger)
    end
  end

  describe 'the lines Servus writes about a call' do
    it "writes the call and success lines through the service's own logger" do
      klass = service('SucceedingEngineService', logger: engine_logger) { success({}) }

      klass.call(amount: 1)

      expect(engine_logger.messages).to include(
        a_string_matching(/\AINFO Calling SucceedingEngineService with args/),
        a_string_matching(/\AINFO SucceedingEngineService succeeded in/)
      )
      expect(default_logger.messages).to be_empty
    end

    it "writes the failure line through the service's own logger" do
      klass = service('FailingEngineService', logger: engine_logger) { failure('nope') }

      klass.call

      expect(engine_logger.messages).to include(a_string_matching(/\AWARN FailingEngineService failed in/))
      expect(default_logger.messages).to be_empty
    end

    it "writes the guard failure line through the service's own logger" do
      klass = service('GuardedEngineService', logger: engine_logger) do
        enforce_truthy!(on: Struct.new(:active).new(false), check: :active)
        success({})
      end

      klass.call

      expect(engine_logger.messages).to include(a_string_matching(/\AWARN GuardedEngineService guard failed/))
      expect(default_logger.messages).to be_empty
    end

    it "writes the uncaught exception line through the service's own logger" do
      klass = service('RaisingEngineService', logger: engine_logger) { raise ArgumentError, 'boom' }

      expect { klass.call }.to raise_error(ArgumentError)

      expect(engine_logger.messages).to include(
        a_string_matching(/\AERROR RaisingEngineService uncaught exception: ArgumentError/)
      )
    end

    it 'splits a call chain between the host logger and the engine logger' do
      service('MixedEngineService', logger: engine_logger) { success({}) }
      host = service('MixedHostService') do
        MixedEngineService.call
        success({})
      end

      host.call

      expect(engine_logger.messages).to all(include('MixedEngineService'))
      expect(default_logger.messages).to all(include('MixedHostService'))
      expect(engine_logger.messages.size).to eq(2)
      expect(default_logger.messages.size).to eq(2)
    end

    it "uses the engine service's own logger when the host calls it from a spawned thread" do
      service('ThreadedEngineService', logger: engine_logger) { success({}) }
      host = service('ThreadedHostService') do
        Thread.new { ThreadedEngineService.call }.join
        success({})
      end

      host.call

      expect(engine_logger.messages).to all(include('ThreadedEngineService'))
      expect(default_logger.messages).to all(include('ThreadedHostService'))
      expect(engine_logger.messages.size).to eq(2)
      expect(default_logger.messages.size).to eq(2)
    end
  end
end

RSpec.describe Servus::Base, 'default logger' do
  it 'is the configured logger' do
    expect(described_class.logger).to be(Servus.logger)
  end
end
