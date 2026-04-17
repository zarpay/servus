# frozen_string_literal: true

RSpec.describe Servus::Guards::TruthyGuard do
  let(:test_class) do
    Struct.new(:active, :verified, :confirmed, keyword_init: true) do
      def self.name
        'TestUser'
      end
    end
  end

  describe '#test' do
    context 'with single attribute' do
      it 'passes when attribute is truthy' do
        object = test_class.new(active: true)
        guard = described_class.new(on: object, check: :active)

        expect(guard.test(on: object, check: :active)).to be true
      end

      it 'fails when attribute is false' do
        object = test_class.new(active: false)
        guard = described_class.new(on: object, check: :active)

        expect(guard.test(on: object, check: :active)).to be false
      end

      it 'fails when attribute is nil' do
        object = test_class.new(active: nil)
        guard = described_class.new(on: object, check: :active)

        expect(guard.test(on: object, check: :active)).to be false
      end

      it 'passes when attribute is a truthy value' do
        object = test_class.new(active: 'yes')
        guard = described_class.new(on: object, check: :active)

        expect(guard.test(on: object, check: :active)).to be true
      end
    end

    context 'with multiple attributes' do
      it 'passes when all attributes are truthy' do
        object = test_class.new(active: true, verified: true, confirmed: true)
        guard = described_class.new(on: object, check: %i[active verified confirmed])

        expect(guard.test(on: object, check: %i[active verified confirmed])).to be true
      end

      it 'fails when any attribute is falsey' do
        object = test_class.new(active: true, verified: false, confirmed: true)
        guard = described_class.new(on: object, check: %i[active verified confirmed])

        expect(guard.test(on: object, check: %i[active verified confirmed])).to be false
      end

      it 'fails when first attribute is falsey' do
        object = test_class.new(active: false, verified: true, confirmed: true)
        guard = described_class.new(on: object, check: %i[active verified confirmed])

        expect(guard.test(on: object, check: %i[active verified confirmed])).to be false
      end
    end
  end

  describe '#error' do
    it 'returns a GuardError with correct metadata' do
      object = test_class.new(active: false)
      guard = described_class.new(on: object, check: :active)
      error = guard.error

      expect(error).to be_a(Servus::Support::Errors::GuardError)
      expect(error.detail).to eq('must_be_truthy')
      expect(error.http_status).to eq(422)
    end

    it 'includes class name in error message' do
      object = test_class.new(active: false)
      guard = described_class.new(on: object, check: :active)

      expect(guard.error.message).to include('TestUser')
    end

    it 'includes attribute name in error message' do
      object = test_class.new(active: false)
      guard = described_class.new(on: object, check: :active)

      expect(guard.error.message).to include('active')
    end

    it 'includes actual value in error message' do
      object = test_class.new(active: false)
      guard = described_class.new(on: object, check: :active)

      expect(guard.error.message).to include('false')
    end

    context 'with multiple attributes' do
      it 'shows first failing attribute in message' do
        object = test_class.new(active: true, verified: false, confirmed: true)
        guard = described_class.new(on: object, check: %i[active verified confirmed])

        expect(guard.error.message).to include('verified')
        expect(guard.error.message).not_to include('confirmed')
      end
    end
  end

  describe 'method registration' do
    it 'defines enforce_truthy! on Servus::Guards' do
      expect(Servus::Guards.method_defined?(:enforce_truthy!)).to be true
    end

    it 'defines check_truthy? on Servus::Guards' do
      expect(Servus::Guards.method_defined?(:check_truthy?)).to be true
    end
  end
end
