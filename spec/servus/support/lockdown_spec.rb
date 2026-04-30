# frozen_string_literal: true

require 'spec_helper'

# Verifies that callers cannot bypass {Servus::Base.call} by instantiating a
# service and invoking its `#call` directly. Doing so would skip argument
# validation, logging, benchmarking, guard handling, result validation, and
# event emission. The spec_helper disables lockdown for the rest of the
# suite, so we re-enable it inside this example group to exercise the
# production-facing behavior.
RSpec.describe Servus::Support::Lockdown do
  around do |example|
    Servus.config.lockdown_enabled = true
    example.run
  ensure
    Servus.config.lockdown_enabled = false
  end

  # Named constant so the validator can resolve a schema path (anonymous
  # classes have nil #name). Defined lazily inside the around block so
  # PrivateCall privatizes the instance `#call` at definition time.
  let(:service_class) do
    stub_const('LockdownTestService', Class.new(Servus::Base) do
      def initialize(**); end

      def call
        success(nil)
      end
    end)
  end

  it 'raises when calling .new directly on a service subclass' do
    expect { service_class.new }.to raise_error(NoMethodError, /private method/)
  end

  it 'raises when calling the instance #call after obtaining an instance' do
    instance = service_class.send(:new)
    expect { instance.call }.to raise_error(NoMethodError, /private method/)
  end

  it 'still allows invocation through the class method .call' do
    result = service_class.call
    expect(result).to be_success
  end
end
