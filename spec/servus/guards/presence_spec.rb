# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Servus::Guards::PresenceGuard do
  describe '#test' do
    context 'with all present values' do
      it 'returns true for non-nil values' do
        guard = described_class.new(user: 'user123', account: 'account456')
        expect(guard.test(user: 'user123', account: 'account456')).to be true
      end

      it 'returns true for non-empty strings' do
        guard = described_class.new(email: 'test@example.com')
        expect(guard.test(email: 'test@example.com')).to be true
      end

      it 'returns true for non-empty arrays' do
        guard = described_class.new(items: [1, 2, 3])
        expect(guard.test(items: [1, 2, 3])).to be true
      end

      it 'returns true for non-empty hashes' do
        guard = described_class.new(data: { key: 'value' })
        expect(guard.test(data: { key: 'value' })).to be true
      end

      it 'returns true for numeric values including zero' do
        guard = described_class.new(amount: 0)
        expect(guard.test(amount: 0)).to be true
      end

      it 'returns true for false boolean' do
        guard = described_class.new(flag: false)
        expect(guard.test(flag: false)).to be true
      end
    end

    context 'with nil values' do
      it 'returns false for nil' do
        guard = described_class.new(user: nil)
        expect(guard.test(user: nil)).to be false
      end

      it 'returns false when any value is nil' do
        guard = described_class.new(user: 'user123', account: nil)
        expect(guard.test(user: 'user123', account: nil)).to be false
      end
    end

    context 'with empty values' do
      it 'returns false for empty string' do
        guard = described_class.new(email: '')
        expect(guard.test(email: '')).to be false
      end

      it 'returns false for empty array' do
        guard = described_class.new(items: [])
        expect(guard.test(items: [])).to be false
      end

      it 'returns false for empty hash' do
        guard = described_class.new(data: {})
        expect(guard.test(data: {})).to be false
      end

      it 'returns false when any value is empty' do
        guard = described_class.new(user: 'user123', email: '')
        expect(guard.test(user: 'user123', email: '')).to be false
      end
    end

    context 'with multiple values' do
      it 'returns true when all values are present' do
        guard = described_class.new(
          user: 'user123',
          account: 'account456',
          device: 'device789'
        )
        expect(guard.test(
                 user: 'user123',
                 account: 'account456',
                 device: 'device789'
               )).to be true
      end

      it 'returns false when any value is missing' do
        guard = described_class.new(
          user: 'user123',
          account: nil,
          device: 'device789'
        )
        expect(guard.test(
                 user: 'user123',
                 account: nil,
                 device: 'device789'
               )).to be false
      end
    end
  end

  describe '#error' do
    it 'returns GuardError with correct metadata' do
      guard = described_class.new(user: nil)
      error = guard.error

      expect(error).to be_a(Servus::Support::Errors::GuardError)
      expect(error.detail).to eq('must_be_present')
      expect(error.http_status).to eq(422)
    end

    it 'shows first failing key with nil value' do
      guard = described_class.new(user: nil, account: nil)
      expect(guard.error.message).to eq('user must be present (got nil)')
    end

    it 'shows first failing key with empty string value' do
      guard = described_class.new(email: '')
      expect(guard.error.message).to eq('email must be present (got "")')
    end

    it 'shows first failing key with empty array value' do
      guard = described_class.new(items: [])
      expect(guard.error.message).to eq('items must be present (got [])')
    end

    it 'shows first failing key when multiple fail' do
      guard = described_class.new(user: 'present', account: nil, device: '')
      expect(guard.error.message).to eq('account must be present (got nil)')
    end
  end

  describe 'metadata' do
    it 'has correct HTTP status' do
      expect(described_class.http_status_code).to eq(422)
    end

    it 'has correct error code' do
      expect(described_class.error_code_value).to eq('must_be_present')
    end
  end

  describe 'method definition' do
    it 'defines enforce_presence! on Servus::Guards' do
      expect(Servus::Guards.method_defined?(:enforce_presence!)).to be true
    end

    it 'defines check_presence? on Servus::Guards' do
      expect(Servus::Guards.method_defined?(:check_presence?)).to be true
    end
  end
end
