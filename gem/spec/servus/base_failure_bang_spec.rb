# frozen_string_literal: true

require 'spec_helper'
require 'active_support/core_ext/object/json'

RSpec.describe Servus::Base, '#failure!' do
  after { Servus::Events::Bus.clear }

  let(:service_class) do
    Class.new(described_class) do
      def initialize(open: false, steps: [])
        @open = open
        @steps = steps
      end

      def call
        account_open!
        @steps << :withdrew
        success({ withdrawn: true })
      end

      private

      def account_open!
        return if @open

        failure!('Account is closed', data: { reason: 'closed' },
                                      type: Servus::Support::Errors::UnprocessableEntityError)
      end
    end
  end

  it 'ends the service from a method called by call' do
    steps = []
    result = service_class.call(steps:)

    expect(steps).to be_empty
    expect(result).not_to be_success
  end

  it 'answers the same response as failure' do
    result = service_class.call

    expect(result.error).to be_a(Servus::Support::Errors::UnprocessableEntityError)
    expect(result.error.message).to eq('Account is closed')
    expect(result.data.reason).to eq('closed')
  end

  it 'leaves a passing check to continue' do
    expect(service_class.call(open: true)).to be_success
  end

  it "uses the error type's default message" do
    klass = Class.new(described_class) do
      def call = failure!(type: Servus::Support::Errors::NotFoundError)
    end

    expect(klass.call.error.message).to eq('Not found')
  end

  it 'is logged as a failed result' do
    allow(Servus::Support::Logger).to receive(:log_result)

    service_class.call

    expect(Servus::Support::Logger).to have_received(:log_result)
      .with(service_class, having_attributes(success?: false), kind_of(Numeric))
  end

  it 'emits the events declared on failure' do
    klass = Class.new(described_class) do
      emits :account_refused, on: :failure

      def call = failure!('refused')
    end
    allow(Servus::Events::Bus).to receive(:emit)

    klass.call

    expect(Servus::Events::Bus).to have_received(:emit).with(:account_refused, anything)
  end

  it 'validates its data against the failure schema' do
    klass = Class.new(described_class) do
      schema failure: { type: 'object', required: %w[reason], properties: { reason: { type: 'string' } } }

      def call = failure!('refused', data: { reason: 123 })
    end

    expect { klass.call }.to raise_error(Servus::Base::ValidationError, /Invalid failure structure/)
  end

  it 'is not rescued as an exception, and runs ensure' do
    ran = []
    klass = Class.new(described_class) do
      define_method(:call) do
        failure!('refused')
      rescue StandardError
        success({ rescued: true })
      ensure
        ran << :ensure
      end
    end

    expect(klass.call).not_to be_success
    expect(ran).to eq([:ensure])
  end

  it 'ends only the service that called it' do
    inner = Class.new(described_class) do
      def call = failure!('inner refused')
    end
    outer = Class.new(described_class) do
      define_method(:call) do
        result = inner.call
        success({ inner_failed: !result.success? })
      end
    end

    result = outer.call

    expect(result).to be_success
    expect(result.data.inner_failed).to be true
  end

  it 'passes through rescue_from untouched' do
    klass = Class.new(described_class) do
      rescue_from ArgumentError

      def call = failure!('refused')
    end

    expect(klass.call.error.message).to eq('refused')
  end
end
