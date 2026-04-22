# frozen_string_literal: true

require 'spec_helper'

module ServiceHelpersSpecSupport
  class InnerService < Servus::Base
    def initialize(should_fail: false)
      @should_fail = should_fail
    end

    def call
      return failure('Inner went boom', type: Servus::Support::Errors::NotFoundError) if @should_fail

      success(value: 42)
    end
  end

  class OuterService < Servus::Base
    def initialize(should_fail: false)
      @should_fail = should_fail
    end

    def call
      data = call!(InnerService, should_fail: @should_fail)
      success(value: data.value)
    end
  end
end

RSpec.describe Servus::Helpers::ServiceHelpers do
  describe '#call!' do
    subject(:result) { ServiceHelpersSpecSupport::OuterService.call(should_fail: should_fail) }

    context 'when the sub-service succeeds' do
      let(:should_fail) { false }

      it 'lets the outer service proceed' do
        expect(result).to be_success
      end

      it "exposes the sub-service's data to the caller" do
        expect(result.data.value).to eq(42)
      end
    end

    context 'when the sub-service fails' do
      let(:should_fail) { true }

      it 'halts the outer service' do
        expect(result).not_to be_success
      end

      it "passes the sub-service's failure through untouched" do
        expect(result.error).to be_a(Servus::Support::Errors::NotFoundError)
        expect(result.error.message).to eq('Inner went boom')
      end
    end

    it 'is mixed into Servus::Base' do
      expect(Servus::Base.instance_method(:call!)).not_to be_nil
    end
  end
end
