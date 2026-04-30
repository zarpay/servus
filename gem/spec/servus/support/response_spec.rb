# frozen_string_literal: true

RSpec.describe Servus::Support::Response do
  describe '#success?' do
    it 'returns true for a successful response' do
      response = described_class.new(true, { user: 'Alice' }, nil)
      expect(response.success?).to be true
    end

    it 'returns false for a failed response' do
      error = Servus::Support::Errors::ServiceError.new('error')
      response = described_class.new(false, nil, error)
      expect(response.success?).to be false
    end
  end

  describe '#failure?' do
    it 'returns true for a failed response' do
      error = Servus::Support::Errors::ServiceError.new('error')
      response = described_class.new(false, nil, error)
      expect(response.failure?).to be true
    end

    it 'returns false for a successful response' do
      response = described_class.new(true, { result: 'ok' }, nil)
      expect(response.failure?).to be false
    end
  end

  describe '#data wrapping' do
    it 'wraps Hash data in a DataObject' do
      response = described_class.new(true, { user: 'Alice' }, nil)
      expect(response.data).to be_a(Servus::Support::DataObject)
    end

    it 'returns nil when data is nil' do
      error = Servus::Support::Errors::ServiceError.new('error')
      response = described_class.new(false, nil, error)
      expect(response.data).to be_nil
    end

    it 'returns non-Hash data unchanged' do
      response = described_class.new(true, 'plain string', nil)
      expect(response.data).to eq('plain string')
      expect(response.data).not_to be_a(Servus::Support::DataObject)
    end

    it 'supports accessor-style access through data' do
      response = described_class.new(true, { user: 'Alice', token: 'abc123' }, nil)
      expect(response.data.user).to eq('Alice')
      expect(response.data.token).to eq('abc123')
    end

    it 'does not delegate data keys to the response itself' do
      response = described_class.new(true, { user: 'Alice' }, nil)
      expect { response.user }.to raise_error(NoMethodError)
    end
  end
end
