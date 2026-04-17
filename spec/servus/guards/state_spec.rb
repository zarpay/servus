# frozen_string_literal: true

RSpec.describe Servus::Guards::StateGuard do
  let(:test_class) do
    Struct.new(:status, :state, :tier, keyword_init: true) do
      def self.name
        'TestOrder'
      end
    end
  end

  describe '#test' do
    context 'with single expected value' do
      it 'passes when attribute matches expected value' do
        object = test_class.new(status: :pending)
        guard = described_class.new(on: object, check: :status, is: :pending)

        expect(guard.test(on: object, check: :status, is: :pending)).to be true
      end

      it 'fails when attribute does not match expected value' do
        object = test_class.new(status: :shipped)
        guard = described_class.new(on: object, check: :status, is: :pending)

        expect(guard.test(on: object, check: :status, is: :pending)).to be false
      end

      it 'passes with string values' do
        object = test_class.new(status: 'active')
        guard = described_class.new(on: object, check: :status, is: 'active')

        expect(guard.test(on: object, check: :status, is: 'active')).to be true
      end

      it 'fails when symbol does not match string' do
        object = test_class.new(status: :active)
        guard = described_class.new(on: object, check: :status, is: 'active')

        expect(guard.test(on: object, check: :status, is: 'active')).to be false
      end
    end

    context 'with multiple expected values' do
      it 'passes when attribute matches any expected value' do
        object = test_class.new(status: :trial)
        guard = described_class.new(on: object, check: :status, is: %i[active trial])

        expect(guard.test(on: object, check: :status, is: %i[active trial])).to be true
      end

      it 'passes when attribute matches first expected value' do
        object = test_class.new(status: :active)
        guard = described_class.new(on: object, check: :status, is: %i[active trial])

        expect(guard.test(on: object, check: :status, is: %i[active trial])).to be true
      end

      it 'fails when attribute matches none of expected values' do
        object = test_class.new(status: :suspended)
        guard = described_class.new(on: object, check: :status, is: %i[active trial])

        expect(guard.test(on: object, check: :status, is: %i[active trial])).to be false
      end
    end
  end

  describe '#error' do
    context 'with single expected value' do
      it 'returns a GuardError with correct metadata' do
        object = test_class.new(status: :shipped)
        guard = described_class.new(on: object, check: :status, is: :pending)
        error = guard.error

        expect(error).to be_a(Servus::Support::Errors::GuardError)
        expect(error.detail).to eq('invalid_state')
        expect(error.http_status).to eq(422)
      end

      it 'includes class name in error message' do
        object = test_class.new(status: :shipped)
        guard = described_class.new(on: object, check: :status, is: :pending)

        expect(guard.error.message).to include('TestOrder')
      end

      it 'includes attribute name in error message' do
        object = test_class.new(status: :shipped)
        guard = described_class.new(on: object, check: :status, is: :pending)

        expect(guard.error.message).to include('status')
      end

      it 'includes expected value in error message' do
        object = test_class.new(status: :shipped)
        guard = described_class.new(on: object, check: :status, is: :pending)

        expect(guard.error.message).to include('pending')
      end

      it 'includes actual value in error message' do
        object = test_class.new(status: :shipped)
        guard = described_class.new(on: object, check: :status, is: :pending)

        expect(guard.error.message).to include('shipped')
      end
    end

    context 'with multiple expected values' do
      it 'shows "one of" in error message' do
        object = test_class.new(status: :suspended)
        guard = described_class.new(on: object, check: :status, is: %i[active trial])

        expect(guard.error.message).to include('one of')
      end

      it 'lists all expected values in error message' do
        object = test_class.new(status: :suspended)
        guard = described_class.new(on: object, check: :status, is: %i[active trial])

        expect(guard.error.message).to include('active')
        expect(guard.error.message).to include('trial')
      end

      it 'shows actual value in error message' do
        object = test_class.new(status: :suspended)
        guard = described_class.new(on: object, check: :status, is: %i[active trial])

        expect(guard.error.message).to include('suspended')
      end
    end
  end

  describe 'method registration' do
    it 'defines enforce_state! on Servus::Guards' do
      expect(Servus::Guards.method_defined?(:enforce_state!)).to be true
    end

    it 'defines check_state? on Servus::Guards' do
      expect(Servus::Guards.method_defined?(:check_state?)).to be true
    end
  end
end
