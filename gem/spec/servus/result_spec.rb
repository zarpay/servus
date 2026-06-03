# frozen_string_literal: true

RSpec.describe Servus::Result do
  describe '.success' do
    it 'returns a successful Result' do
      result = described_class.success({ user_id: 1 })

      expect(result).to be_a(described_class)
      expect(result.success?).to be true
      expect(result.failure?).to be false
      expect(result.error).to be_nil
    end

    it 'wraps Hash data in a DataObject for accessor-style access' do
      result = described_class.success({ user: 'Alice', token: 'abc123' })

      expect(result.data).to be_a(Servus::Support::DataObject)
      expect(result.data.user).to eq('Alice')
      expect(result.data.token).to eq('abc123')
    end

    it 'allows nil data without arguments' do
      result = described_class.success

      expect(result.success?).to be true
      expect(result.data).to be_nil
    end

    it 'passes non-Hash data through unchanged' do
      result = described_class.success('plain string')

      expect(result.data).to eq('plain string')
      expect(result.data).not_to be_a(Servus::Support::DataObject)
    end
  end

  describe '.failure' do
    it 'returns a failure Result with a default ServiceError' do
      result = described_class.failure('Boom')

      expect(result.failure?).to be true
      expect(result.success?).to be false
      expect(result.error).to be_a(Servus::Support::Errors::ServiceError)
      expect(result.error.message).to eq('Boom')
      expect(result.data).to be_nil
    end

    it 'uses the error type default message when message is omitted' do
      result = described_class.failure(type: Servus::Support::Errors::NotFoundError)

      expect(result.error).to be_a(Servus::Support::Errors::NotFoundError)
      expect(result.error.message).not_to be_nil
    end

    it 'accepts a custom error type' do
      result = described_class.failure('Bad input', type: Servus::Support::Errors::BadRequestError)

      expect(result.error).to be_a(Servus::Support::Errors::BadRequestError)
      expect(result.error.message).to eq('Bad input')
    end

    it 'attaches structured failure data when data: is given' do
      result = described_class.failure('Declined', data: { reason: 'insufficient_funds' })

      expect(result.failure?).to be true
      expect(result.data).to be_a(Servus::Support::DataObject)
      expect(result.data.reason).to eq('insufficient_funds')
      expect(result.error.message).to eq('Declined')
    end
  end

  describe 'direct construction' do
    it 'supports building a Result with a pre-existing error instance' do
      error = Servus::Support::Errors::ConflictError.new('duplicate')
      result = described_class.new(false, nil, error)

      expect(result.failure?).to be true
      expect(result.error).to equal(error)
    end
  end

  describe 'backwards-compatible alias' do
    it 'exposes the same class as Servus::Support::Response' do
      expect(Servus::Support::Response).to equal(described_class)
    end

    it 'accepts construction via the legacy constant' do
      result = Servus::Support::Response.new(true, { ok: true }, nil)

      expect(result).to be_a(described_class)
      expect(result.success?).to be true
      expect(result.data.ok).to be true
    end
  end

  describe 'inside Servus::Base' do
    it 'returns a Servus::Result from a service call' do
      service_class = Class.new(Servus::Base) do
        def call
          success(value: 42)
        end
      end
      stub_const('ResultSpec::Successful::Service', service_class)

      result = service_class.call

      expect(result).to be_a(described_class)
      expect(result.success?).to be true
      expect(result.data.value).to eq(42)
    end

    it 'returns a Servus::Result for failures' do
      service_class = Class.new(Servus::Base) do
        def call
          failure('Nope', type: Servus::Support::Errors::NotFoundError)
        end
      end
      stub_const('ResultSpec::Failing::Service', service_class)

      result = service_class.call

      expect(result).to be_a(described_class)
      expect(result.failure?).to be true
      expect(result.error).to be_a(Servus::Support::Errors::NotFoundError)
    end
  end
end
