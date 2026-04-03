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

  describe '#method_missing / data key access' do
    let(:response) { described_class.new(true, { user: 'Alice', token: 'abc123' }, nil) }

    it 'allows access to symbol keys as methods' do
      expect(response.user).to eq('Alice')
      expect(response.token).to eq('abc123')
    end

    it 'allows access to string keys as methods' do
      response = described_class.new(true, { 'name' => 'Bob' }, nil)
      expect(response.name).to eq('Bob')
    end

    it 'falls through to super for unknown keys' do
      expect { response.nonexistent }.to raise_error(NoMethodError)
    end

    it 'returns nil data when response is a failure (no method_missing delegation)' do
      error = Servus::Support::Errors::ServiceError.new('error')
      response = described_class.new(false, nil, error)
      expect { response.user }.to raise_error(NoMethodError)
    end
  end

  describe '#respond_to_missing?' do
    let(:response) { described_class.new(true, { user: 'Alice' }, nil) }

    it 'returns true for data keys' do
      expect(response.respond_to?(:user)).to be true
    end

    it 'returns false for unknown keys' do
      expect(response.respond_to?(:nonexistent)).to be false
    end
  end
end
