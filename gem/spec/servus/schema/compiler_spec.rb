# frozen_string_literal: true

RSpec.describe Servus::Schema::Compiler, :schema_registry do
  subject(:compile) { described_class.new(context: context).compile(schema) }

  let(:context) { nil }

  before do
    Servus::Schema.register('core', {
                              '$defs' => {
                                'amount' => { 'type' => 'integer', 'minimum' => 0, 'description' => 'An amount' },
                                'timestamp' => { 'type' => 'string', 'format' => 'date-time' }
                              }
                            })
  end

  describe 'schemas without refs' do
    let(:schema) do
      { 'type' => 'object', 'properties' => { 'name' => { 'type' => 'string' } }, 'required' => ['name'] }
    end

    it 'returns an equal schema' do
      expect(compile).to eq(schema)
    end

    it 'consults no fragments' do
      expect { compile }.not_to(change { Servus::Schema.cache.size })
    end
  end

  describe 'whole-fragment refs' do
    let(:schema) { { '$ref' => '#/core' } }

    it 'resolves to the entire fragment' do
      expect(compile['$defs']['amount']['type']).to eq('integer')
    end
  end

  describe 'path refs' do
    let(:schema) do
      { 'type' => 'object', 'properties' => { 'fee' => { '$ref' => '#/core/$defs/amount' } } }
    end

    it 'resolves to the fragment at that path' do
      expect(compile['properties']['fee']).to eq(
        { 'type' => 'integer', 'minimum' => 0, 'description' => 'An amount' }
      )
    end

    it 'leaves no $ref in the output' do
      expect(compile.to_s).not_to include('$ref')
    end
  end

  describe 'transitive refs' do
    before do
      Servus::Schema.register('money', {
                                '$defs' => {
                                  'price' => { '$ref' => '#/core/$defs/amount' }
                                }
                              })
    end

    let(:schema) { { '$ref' => '#/money/$defs/price' } }

    it 'follows a ref that points at another ref' do
      expect(compile).to eq({ 'type' => 'integer', 'minimum' => 0, 'description' => 'An amount' })
    end
  end

  describe 'refs inside arrays' do
    let(:schema) do
      { 'anyOf' => [{ '$ref' => '#/core/$defs/amount' }, { 'type' => 'null' }] }
    end

    it 'resolves each element' do
      expect(compile['anyOf'].first['type']).to eq('integer')
      expect(compile['anyOf'].last).to eq({ 'type' => 'null' })
    end
  end

  describe 'refs nested deep in the document' do
    let(:schema) do
      {
        'type' => 'object',
        'properties' => {
          'items' => {
            'type' => 'array',
            'items' => { 'type' => 'object', 'properties' => { 'fee' => { '$ref' => '#/core/$defs/amount' } } }
          }
        }
      }
    end

    it 'resolves them' do
      expect(compile.dig('properties', 'items', 'items', 'properties', 'fee', 'type')).to eq('integer')
    end
  end

  describe 'sibling properties' do
    let(:schema) do
      { '$ref' => '#/core/$defs/amount', 'description' => 'The fee charged' }
    end

    it 'overrides the resolved value' do
      expect(compile['description']).to eq('The fee charged')
    end

    it 'keeps the keys it does not override' do
      expect(compile['type']).to eq('integer')
      expect(compile['minimum']).to eq(0)
    end

    it 'resolves a sibling that is itself a ref' do
      schema = {
        '$ref' => '#/core/$defs/amount',
        'properties' => { 'at' => { '$ref' => '#/core/$defs/timestamp' } }
      }

      result = described_class.new.compile(schema)

      expect(result['properties']['at']['format']).to eq('date-time')
    end

    # The memo holds the resolved target *before* siblings are merged, so the
    # same ref used with different siblings must not contaminate other sites.
    it 'does not leak overrides between sites that share a ref' do
      schema = {
        'properties' => {
          'a' => { '$ref' => '#/core/$defs/amount', 'description' => 'A' },
          'b' => { '$ref' => '#/core/$defs/amount', 'description' => 'B' },
          'c' => { '$ref' => '#/core/$defs/amount' }
        }
      }

      result = described_class.new.compile(schema)

      expect(result['properties']['a']['description']).to eq('A')
      expect(result['properties']['b']['description']).to eq('B')
      expect(result['properties']['c']['description']).to eq('An amount')
    end
  end

  describe 'memoization' do
    let(:schema) do
      {
        'properties' => {
          'a' => { '$ref' => '#/core/$defs/amount' },
          'b' => { '$ref' => '#/core/$defs/amount' },
          'c' => { '$ref' => '#/core/$defs/amount' }
        }
      }
    end

    it 'expands a repeated ref once' do
      expect { compile }.to change { Servus::Schema.cache.size }.by(1)
    end

    it 'reuses the memo across separate compiles' do
      described_class.new.compile(schema)

      expect { described_class.new.compile(schema) }
        .not_to(change { Servus::Schema.cache.size })
    end
  end

  describe 'cycles' do
    it 'raises on a direct self-reference' do
      Servus::Schema.register('a', { 'self' => { '$ref' => '#/a/self' } })

      expect { described_class.new.compile({ '$ref' => '#/a/self' }) }
        .to raise_error(Servus::Schema::CircularReferenceError, %r{#/a/self -> #/a/self})
    end

    it 'raises on an indirect cycle and names every hop' do
      Servus::Schema.register('a', { 'node' => { '$ref' => '#/b/node' } })
      Servus::Schema.register('b', { 'node' => { '$ref' => '#/a/node' } })

      expect { described_class.new.compile({ '$ref' => '#/a/node' }) }
        .to raise_error(
          Servus::Schema::CircularReferenceError,
          %r{#/a/node -> #/b/node -> #/a/node}
        )
    end
  end

  describe 'depth' do
    # A depth-counter-only implementation cannot tell this apart from a cycle.
    it 'compiles a long acyclic chain of fragments' do
      60.times do |i|
        target = i.zero? ? { 'type' => 'integer' } : { '$ref' => "#/chain_#{i - 1}/node" }
        Servus::Schema.register("chain_#{i}", { 'node' => target })
      end

      expect(described_class.new.compile({ '$ref' => '#/chain_59/node' }))
        .to eq({ 'type' => 'integer' })
    end

    it 'raises DepthExceededError, not CircularReferenceError, on runaway nesting' do
      deep = { 'type' => 'integer' }
      (described_class::MAX_DEPTH + 5).times { deep = { 'properties' => { 'x' => deep } } }

      expect { described_class.new.compile(deep) }
        .to raise_error(Servus::Schema::DepthExceededError)
    end
  end

  describe 'errors' do
    let(:context) { 'Treasury::TransferGold::Service arguments schema' }

    context 'when the fragment key is not registered' do
      let(:schema) { { '$ref' => '#/cor/$defs/amount' } }

      it 'names the key, the ref, the context and a suggestion' do
        expect { compile }.to raise_error(Servus::Schema::UnknownKeyError) { |error|
          expect(error.message).to include('"cor"')
          expect(error.message).to include('Did you mean: "core"')
          expect(error.message).to include(context)
        }
      end
    end

    context 'when the path within a known fragment is absent' do
      let(:schema) { { '$ref' => '#/core/$defs/nope' } }

      it 'lists what was available at the failing segment' do
        expect { compile }.to raise_error(Servus::Schema::RefNotFoundError) { |error|
          expect(error.message).to include('"nope"')
          expect(error.message).to include('Available keys: "amount", "timestamp"')
        }
      end
    end

    context 'when the failure is reached through another ref' do
      let(:schema) { { '$ref' => '#/outer/node' } }

      before { Servus::Schema.register('outer', { 'node' => { '$ref' => '#/core/$defs/nope' } }) }

      it 'reports the resolution path' do
        expect { compile }.to raise_error(
          Servus::Schema::RefNotFoundError,
          %r{resolution path: #/outer/node -> #/core/\$defs/nope}
        )
      end
    end

    # Which ref forms are rejected, and why, belongs to Servus::Schema::Ref.
    # What matters here is that the compiler surfaces that rejection with the
    # context of the schema being compiled attached.
    context 'with an unsupported ref form' do
      let(:schema) { { 'properties' => { 'fee' => { '$ref' => '#/$defs/amount' } } } }

      it 'raises InvalidRefError naming the schema being compiled' do
        expect { compile }.to raise_error(Servus::Schema::InvalidRefError) { |error|
          expect(error.message).to include('local ref')
          expect(error.message).to include(context)
        }
      end
    end
  end

  describe 'fragment metadata' do
    before do
      Servus::Schema.register('doc', {
                                '$schema' => 'http://json-schema.org/draft-07/schema#',
                                '$id' => 'doc',
                                'type' => 'integer'
                              })
    end

    # json-schema raises SchemaError on a $schema URI it does not recognize,
    # at any position in the document, so a spliced fragment must not carry one.
    it 'strips $schema and $id from a spliced fragment' do
      result = described_class.new.compile({ 'properties' => { 'x' => { '$ref' => '#/doc' } } })

      expect(result['properties']['x']).to eq({ 'type' => 'integer' })
    end

    it 'produces a schema json-schema can validate against' do
      result = described_class.new.compile(
        { 'type' => 'object', 'properties' => { 'x' => { '$ref' => '#/doc' } } }
      )

      expect(JSON::Validator.fully_validate(result, { 'x' => 'nope' })).not_to be_empty
      expect(JSON::Validator.fully_validate(result, { 'x' => 5 })).to be_empty
    end
  end

  describe 'immutability' do
    let(:schema) { { 'properties' => { 'fee' => { '$ref' => '#/core/$defs/amount' } } } }

    it 'does not hand back the registry object itself' do
      expect(compile['properties']['fee']).not_to equal(Servus::Schema.fetch('core')['$defs']['amount'])
    end
  end
end
