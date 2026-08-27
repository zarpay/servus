# frozen_string_literal: true

RSpec.describe Servus::Schema::Cache do
  subject(:cache) { described_class.new }

  describe '#resolve' do
    it 'returns the block value on a miss' do
      expect(cache.resolve('#/core') { 'resolved' }).to eq('resolved')
    end

    it 'does not call the block again on a hit' do
      cache.resolve('#/core') { 'first' }

      expect(cache.resolve('#/core') { raise 'should not be called' }).to eq('first')
    end

    it 'keys entries independently' do
      cache.resolve('#/a') { 'a' }
      cache.resolve('#/b') { 'b' }

      expect(cache.size).to eq(2)
    end

    it 'caches a falsey resolution rather than recomputing it' do
      cache.resolve('#/core') { false }

      expect(cache.resolve('#/core') { 'recomputed' }).to be(false)
    end

    # A ref that failed part way through must not leave a half-built value
    # behind for the next caller to pick up.
    it 'stores nothing when the block raises' do
      expect { cache.resolve('#/core') { raise 'boom' } }.to raise_error('boom')

      expect(cache.size).to eq(0)
    end
  end

  describe '#invalidate!' do
    it 'drops every entry' do
      cache.resolve('#/core') { 'resolved' }

      cache.invalidate!

      expect(cache.size).to eq(0)
    end

    it 'advances the generation' do
      expect { cache.invalidate! }.to change(cache, :generation).by(1)
    end
  end

  describe '#generation' do
    it 'starts at zero' do
      expect(cache.generation).to eq(0)
    end

    it 'does not move when entries are merely added' do
      expect { cache.resolve('#/core') { 'resolved' } }.not_to change(cache, :generation)
    end
  end
end
