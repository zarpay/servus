# frozen_string_literal: true

RSpec.describe Servus::Guards::FalseyGuard do
  let(:test_class) do
    Struct.new(:banned, :deleted, :flagged, keyword_init: true) do
      def self.name
        'TestPost'
      end
    end
  end

  describe '#test' do
    context 'with single attribute' do
      it 'passes when attribute is false' do
        object = test_class.new(banned: false)
        guard = described_class.new(on: object, check: :banned)

        expect(guard.test).to be true
      end

      it 'passes when attribute is nil' do
        object = test_class.new(banned: nil)
        guard = described_class.new(on: object, check: :banned)

        expect(guard.test).to be true
      end

      it 'fails when attribute is true' do
        object = test_class.new(banned: true)
        guard = described_class.new(on: object, check: :banned)

        expect(guard.test).to be false
      end

      it 'fails when attribute is a truthy value' do
        object = test_class.new(banned: 'yes')
        guard = described_class.new(on: object, check: :banned)

        expect(guard.test).to be false
      end
    end

    context 'with multiple attributes' do
      it 'passes when all attributes are falsey' do
        object = test_class.new(banned: false, deleted: nil, flagged: false)
        guard = described_class.new(on: object, check: %i[banned deleted flagged])

        expect(guard.test).to be true
      end

      it 'fails when any attribute is truthy' do
        object = test_class.new(banned: false, deleted: true, flagged: false)
        guard = described_class.new(on: object, check: %i[banned deleted flagged])

        expect(guard.test).to be false
      end

      it 'fails when first attribute is truthy' do
        object = test_class.new(banned: true, deleted: false, flagged: false)
        guard = described_class.new(on: object, check: %i[banned deleted flagged])

        expect(guard.test).to be false
      end
    end
  end

  describe '#error' do
    it 'returns a GuardError with correct metadata' do
      object = test_class.new(banned: true)
      guard = described_class.new(on: object, check: :banned)
      error = guard.error

      expect(error).to be_a(Servus::Support::Errors::GuardError)
      expect(error.code).to eq('must_be_falsey')
      expect(error.http_status).to eq(422)
    end

    it 'includes class name in error message' do
      object = test_class.new(banned: true)
      guard = described_class.new(on: object, check: :banned)

      expect(guard.error.message).to include('TestPost')
    end

    it 'includes attribute name in error message' do
      object = test_class.new(banned: true)
      guard = described_class.new(on: object, check: :banned)

      expect(guard.error.message).to include('banned')
    end

    it 'includes actual value in error message' do
      object = test_class.new(banned: true)
      guard = described_class.new(on: object, check: :banned)

      expect(guard.error.message).to include('true')
    end

    context 'with multiple attributes' do
      it 'shows first failing attribute in message' do
        object = test_class.new(banned: false, deleted: true, flagged: true)
        guard = described_class.new(on: object, check: %i[banned deleted flagged])

        expect(guard.error.message).to include('deleted')
        expect(guard.error.message).not_to include('flagged')
      end
    end
  end

  describe 'method registration' do
    it 'defines enforce_falsey! on Servus::Guards' do
      expect(Servus::Guards.method_defined?(:enforce_falsey!)).to be true
    end

    it 'defines check_falsey? on Servus::Guards' do
      expect(Servus::Guards.method_defined?(:check_falsey?)).to be true
    end
  end
end
