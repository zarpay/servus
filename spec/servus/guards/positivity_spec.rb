# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Servus::Guards::PositivityGuard do
  describe '#test' do
    context 'with strictly positive numerics' do
      it 'returns true for positive integers' do
        guard = described_class.new(amount: 10)
        expect(guard.test(amount: 10)).to be true
      end

      it 'returns true for positive floats' do
        guard = described_class.new(rate: 0.25)
        expect(guard.test(rate: 0.25)).to be true
      end

      it 'returns true when all values are positive' do
        guard = described_class.new(amount: 10, fee: 1)
        expect(guard.test(amount: 10, fee: 1)).to be true
      end
    end

    context 'with zero, negative, or non-numeric values' do
      it 'returns false for zero' do
        guard = described_class.new(amount: 0)
        expect(guard.test(amount: 0)).to be false
      end

      it 'returns false for negative values' do
        guard = described_class.new(amount: -5)
        expect(guard.test(amount: -5)).to be false
      end

      it 'returns false for nil values' do
        guard = described_class.new(amount: nil)
        expect(guard.test(amount: nil)).to be false
      end

      it 'returns false for non-numeric values' do
        guard = described_class.new(amount: '10')
        expect(guard.test(amount: '10')).to be false
      end

      it 'returns false when any value is non-positive' do
        guard = described_class.new(amount: 10, fee: 0)
        expect(guard.test(amount: 10, fee: 0)).to be false
      end
    end
  end

  describe '#error' do
    it 'returns GuardError with correct metadata' do
      guard = described_class.new(amount: 0)
      error = guard.error

      expect(error).to be_a(Servus::Support::Errors::GuardError)
      expect(error.code).to eq('must_be_positive')
      expect(error.http_status).to eq(422)
    end

    it 'shows first failing key with zero value' do
      guard = described_class.new(amount: 0)
      expect(guard.error.message).to eq('amount must be positive (got 0)')
    end

    it 'shows first failing key with negative value' do
      guard = described_class.new(fee: -1)
      expect(guard.error.message).to eq('fee must be positive (got -1)')
    end

    it 'shows first failing key with nil value' do
      guard = described_class.new(amount: nil)
      expect(guard.error.message).to eq('amount must be positive (got nil)')
    end

    it 'shows first failing key when multiple fail' do
      guard = described_class.new(amount: 10, fee: 0, bonus: -1)
      expect(guard.error.message).to eq('fee must be positive (got 0)')
    end
  end

  describe 'metadata' do
    it 'has correct HTTP status' do
      expect(described_class.http_status_code).to eq(422)
    end

    it 'has correct error code' do
      expect(described_class.error_code_value).to eq('must_be_positive')
    end
  end

  describe 'method definition' do
    it 'defines enforce_positivity! on Servus::Guards' do
      expect(Servus::Guards.method_defined?(:enforce_positivity!)).to be true
    end

    it 'defines check_positivity? on Servus::Guards' do
      expect(Servus::Guards.method_defined?(:check_positivity?)).to be true
    end
  end
end
