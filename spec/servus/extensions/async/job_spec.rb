# frozen_string_literal: true

require 'spec_helper'
require 'active_job'

require 'servus/extensions/async/ext'

RSpec.describe Servus::Extensions::Async::Job, type: :job do
  # Include error modules for easier testing
  let(:errors) { Servus::Extensions::Async::Errors }

  before do
    stub_const('DummyService', Class.new(Servus::Base) do
      def initialize(a:, b:)
        @a = a
        @b = b
      end

      def call
        success("#{@a}, #{@b}")
      end
    end)
  end

  let(:job) { described_class.new }

  it 'calls the correct service with given arguments' do
    expect(DummyService).to receive(:call).with(a: 1, b: 2)

    job.perform(name: 'DummyService', args: { a: 1, b: 2 })
  end

  it 'raises NameError if the service class does not exist' do
    expect {
      job.perform(name: 'NonExistentService', args: {})
    }.to raise_error(errors::ServiceNotFoundError, /Service class 'NonExistentService' not found/)
  end
end
