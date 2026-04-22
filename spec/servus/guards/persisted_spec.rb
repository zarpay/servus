# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Servus::Guards::PersistedGuard do
  let(:record_class) do
    Struct.new(:persisted, :full_messages, keyword_init: true) do
      def persisted?
        persisted
      end

      def errors
        self
      end
    end
  end
  let(:persisted_record) { record_class.new(persisted: true, full_messages: []) }
  let(:unpersisted_record) do
    record_class.new(persisted: false, full_messages: ['Email is invalid', 'Name can\'t be blank'])
  end

  describe '#test' do
    it 'returns true when the record is persisted' do
      guard = described_class.new(record: persisted_record)
      expect(guard.test(record: persisted_record)).to be true
    end

    it 'returns false when the record is not persisted' do
      guard = described_class.new(record: unpersisted_record)
      expect(guard.test(record: unpersisted_record)).to be false
    end
  end

  describe '#error' do
    it 'returns GuardError with correct metadata' do
      guard = described_class.new(record: unpersisted_record)
      error = guard.error

      expect(error).to be_a(Servus::Support::Errors::GuardError)
      expect(error.code).to eq('record_not_persisted')
      expect(error.http_status).to eq(422)
    end

    it 'surfaces the record\'s full error messages as the failure message' do
      guard = described_class.new(record: unpersisted_record)
      expect(guard.error.message).to eq('Email is invalid and Name can\'t be blank')
    end
  end

  describe 'metadata' do
    it 'has correct HTTP status' do
      expect(described_class.http_status_code).to eq(422)
    end

    it 'has correct error code' do
      expect(described_class.error_code_value).to eq('record_not_persisted')
    end
  end

  describe 'method definition' do
    it 'defines enforce_persisted! on Servus::Guards' do
      expect(Servus::Guards.method_defined?(:enforce_persisted!)).to be true
    end

    it 'defines check_persisted? on Servus::Guards' do
      expect(Servus::Guards.method_defined?(:check_persisted?)).to be true
    end
  end
end
