# frozen_string_literal: true

RSpec.describe Servus::Schema, :schema_registry do
  let(:core_fragment) do
    {
      '$defs' => {
        'amount' => { 'type' => 'integer', 'minimum' => 0 },
        'timestamp' => { 'type' => 'string', 'format' => 'date-time' }
      }
    }
  end

  describe '.register' do
    it 'returns the normalized fragment' do
      result = described_class.register('core', core_fragment)

      expect(result).to be_a(ActiveSupport::HashWithIndifferentAccess)
      expect(result[:$defs][:amount][:type]).to eq('integer')
    end

    it 'makes the fragment retrievable by string key' do
      described_class.register('core', core_fragment)

      expect(described_class.fetch('core')).to eq(core_fragment)
    end

    it 'accepts a symbol key and stores it as a string' do
      described_class.register(:core, core_fragment)

      expect(described_class.keys).to eq(['core'])
      expect(described_class.fetch('core')).to eq(core_fragment)
    end

    it 'accepts a symbol-keyed fragment and exposes it indifferently' do
      described_class.register('core', { '$defs': { amount: { type: 'integer' } } })

      expect(described_class.fetch('core')['$defs']['amount']['type']).to eq('integer')
    end

    it 'deep dups so later mutation of the caller hash cannot corrupt the registry' do
      mutable = { '$defs' => { 'amount' => { 'type' => 'integer' } } }
      described_class.register('core', mutable)

      mutable['$defs']['amount']['type'] = 'string'

      expect(described_class.fetch('core')['$defs']['amount']['type']).to eq('integer')
    end

    it 'freezes the stored fragment' do
      described_class.register('core', core_fragment)

      expect(described_class.fetch('core')).to be_frozen
    end

    it 'accepts a key containing :: namespace separators' do
      described_class.register('models::trade', core_fragment)

      expect(described_class.keys).to include('models::trade')
    end

    it 'rejects a key containing a / because it collides with the ref path separator' do
      expect { described_class.register('a/b', core_fragment) }
        .to raise_error(Servus::Schema::InvalidKeyError, %r{a/b})
    end

    it 'rejects a blank key' do
      expect { described_class.register('', core_fragment) }
        .to raise_error(Servus::Schema::InvalidKeyError)
    end

    it 'rejects a non-Hash fragment' do
      expect { described_class.register('core', 'nope') }
        .to raise_error(ArgumentError, /Hash/)
    end
  end

  describe '.register idempotency' do
    it 'is a silent no-op when re-registering an equal value' do
      described_class.register('core', core_fragment)
      generation = described_class.generation

      expect(Servus::Support::Logger).not_to receive(:log_schema_override)
      described_class.register('core', core_fragment.dup)

      expect(described_class.generation).to eq(generation)
    end

    it 'replaces the value and bumps generation when re-registering a different value' do
      described_class.register('core', core_fragment)
      generation = described_class.generation

      allow(Servus::Support::Logger).to receive(:log_schema_override)
      described_class.register('core', { '$defs' => { 'amount' => { 'type' => 'string' } } })

      expect(described_class.fetch('core')['$defs']['amount']['type']).to eq('string')
      expect(described_class.generation).to be > generation
    end

    it 'logs an override when re-registering a different value' do
      described_class.register('core', core_fragment)

      expect(Servus::Support::Logger).to receive(:log_schema_override).with('core')

      described_class.register('core', { '$defs' => {} })
    end
  end

  describe '.fetch' do
    it 'raises UnknownKeyError for an unregistered key' do
      described_class.register('core', core_fragment)

      expect { described_class.fetch('nope') }
        .to raise_error(Servus::Schema::UnknownKeyError, /nope/)
    end

    it 'suggests the nearest registered key' do
      described_class.register('core', core_fragment)

      expect { described_class.fetch('cor') }
        .to raise_error(Servus::Schema::UnknownKeyError, /Did you mean.*core/)
    end

    it 'reports that nothing is registered when the registry is empty' do
      expect { described_class.fetch('core') }
        .to raise_error(Servus::Schema::UnknownKeyError, /no schema fragments are registered/i)
    end
  end

  describe '.fetch with a path' do
    before { described_class.register('core', core_fragment) }

    it 'returns the definition at the path' do
      expect(described_class.fetch('core', '$defs', 'amount'))
        .to eq({ 'type' => 'integer', 'minimum' => 0 })
    end

    it 'accepts symbol segments' do
      expect(described_class.fetch('core', :$defs, :amount)).to be_a(Hash)
    end

    it 'returns the whole fragment when given no path' do
      expect(described_class.fetch('core')).to eq(core_fragment)
    end

    # The alternative — fetching the fragment and calling dig — returns nil on
    # a typo, which is the silent failure this registry exists to avoid.
    it 'raises for a missing path rather than returning nil' do
      expect { described_class.fetch('core', '$defs', 'amnout') }
        .to raise_error(Servus::Schema::RefNotFoundError, /amnout/)
    end

    it 'lists the keys available at the failing segment' do
      expect { described_class.fetch('core', '$defs', 'amnout') }
        .to raise_error(Servus::Schema::RefNotFoundError, /Available keys: "amount", "timestamp"/)
    end

    it 'names the fragment in the error' do
      expect { described_class.fetch('core', 'nope') }
        .to raise_error(Servus::Schema::RefNotFoundError, /"core"/)
    end

    it 'raises when the path runs into a non-Hash' do
      expect { described_class.fetch('core', '$defs', 'amount', 'type', 'deeper') }
        .to raise_error(Servus::Schema::RefNotFoundError)
    end

    it 'still raises UnknownKeyError when the fragment itself is absent' do
      expect { described_class.fetch('nope', '$defs') }
        .to raise_error(Servus::Schema::UnknownKeyError)
    end

    it 'returns fragments with refs left unresolved' do
      described_class.register('money', { '$defs' => { 'price' => { '$ref' => '#/core/$defs/amount' } } })

      expect(described_class.fetch('money', '$defs', 'price'))
        .to eq({ '$ref' => '#/core/$defs/amount' })
    end
  end

  describe '.resolve' do
    before do
      described_class.register('core', core_fragment)
      described_class.register('models::trade', {
                                 '$defs' => {
                                   'representation' => {
                                     'type' => 'object',
                                     'properties' => { 'price' => { '$ref' => '#/core/$defs/amount' } }
                                   }
                                 }
                               })
    end

    it 'returns the definition with refs resolved' do
      expect(described_class.resolve('models::trade', '$defs', 'representation'))
        .to eq({ 'type' => 'object', 'properties' => { 'price' => { 'type' => 'integer', 'minimum' => 0 } } })
    end

    it 'resolves a whole fragment when given no path' do
      expect(described_class.resolve('models::trade').to_s).not_to include('$ref')
    end

    it 'memoizes so repeated lookups are cheap' do
      described_class.resolve('models::trade', '$defs', 'representation')

      expect { described_class.resolve('models::trade', '$defs', 'representation') }
        .not_to(change { described_class.cache.size })
    end

    it 'raises UnknownKeyError for an unregistered fragment' do
      expect { described_class.resolve('nope') }
        .to raise_error(Servus::Schema::UnknownKeyError)
    end

    it 'raises RefNotFoundError for a missing path' do
      expect { described_class.resolve('models::trade', '$defs', 'nope') }
        .to raise_error(Servus::Schema::RefNotFoundError, /Available keys: "representation"/)
    end

    it 'names the address in the error' do
      expect { described_class.resolve('models::trade', '$defs', 'nope') }
        .to raise_error(Servus::Schema::RefNotFoundError, %r{#/models::trade/\$defs/nope})
    end

    it 'produces a schema json-schema can validate against' do
      schema = described_class.resolve('models::trade', '$defs', 'representation')

      expect(JSON::Validator.fully_validate(schema, { 'price' => 5 })).to be_empty
      expect(JSON::Validator.fully_validate(schema, { 'price' => 'no' })).not_to be_empty
    end
  end

  describe '.compile_all' do
    before do
      described_class.register('core', core_fragment)
      described_class.register('models::trade', {
                                 '$defs' => {
                                   'representation' => {
                                     'type' => 'object',
                                     'properties' => { 'price' => { '$ref' => '#/core/$defs/amount' } }
                                   }
                                 }
                               })
    end

    it 'returns every registered fragment keyed by name' do
      expect(described_class.compile_all.keys).to eq(['core', 'models::trade'])
    end

    it 'resolves refs in every fragment' do
      compiled = described_class.compile_all

      expect(compiled.dig('models::trade', '$defs', 'representation', 'properties', 'price'))
        .to eq({ 'type' => 'integer', 'minimum' => 0 })
    end

    it 'leaves no $ref anywhere in the output' do
      expect(described_class.compile_all.to_s).not_to include('$ref')
    end

    it 'serializes to JSON as a single asset' do
      expect { JSON.generate(described_class.compile_all) }.not_to raise_error
    end

    it 'returns an empty hash when nothing is registered' do
      described_class.reset!

      expect(described_class.compile_all).to eq({})
    end

    it 'names the fragment being compiled when one cannot be resolved' do
      described_class.register('broken', { '$defs' => { 'x' => { '$ref' => '#/nope/thing' } } })

      expect { described_class.compile_all }
        .to raise_error(Servus::Schema::UnknownKeyError, /broken/)
    end
  end

  describe '.keys' do
    it 'returns registered keys sorted' do
      described_class.register('zulu', core_fragment)
      described_class.register('alpha', core_fragment)

      expect(described_class.keys).to eq(%w[alpha zulu])
    end
  end

  describe '.ref' do
    it 'builds a whole-fragment ref' do
      expect(described_class.ref('core')).to eq({ '$ref' => '#/core' })
    end

    it 'builds a path ref' do
      expect(described_class.ref('core', '$defs', 'amount'))
        .to eq({ '$ref' => '#/core/$defs/amount' })
    end

    it 'stringifies symbol segments' do
      expect(described_class.ref(:core, :$defs, :amount))
        .to eq({ '$ref' => '#/core/$defs/amount' })
    end
  end

  describe '.reset!' do
    it 'clears the registry and bumps generation' do
      described_class.register('core', core_fragment)
      generation = described_class.generation

      described_class.reset!

      expect(described_class.keys).to be_empty
      expect(described_class.generation).to be > generation
    end
  end

  describe 'thread safety' do
    it 'loses no writes when registering concurrently' do
      keys = (1..50).map { |i| "frag_#{i}" }

      writers = keys.map do |key|
        Thread.new { described_class.register(key, { '$defs' => { 'x' => { 'type' => 'integer' } } }) }
      end
      readers = Array.new(10) { Thread.new { 20.times { described_class.keys } } }

      (writers + readers).each(&:join)

      expect(described_class.keys).to match_array(keys)
    end
  end
end
