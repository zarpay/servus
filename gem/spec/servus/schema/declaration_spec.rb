# frozen_string_literal: true

RSpec.describe Servus::Schema::Declaration, :schema_registry do
  let(:service_class) { stub_const('DeclarationTest::Service', Class.new(Servus::Base)) }

  describe '.schema' do
    it 'stores a declared schema with indifferent access' do
      service_class.schema arguments: { type: 'object', required: ['name'] }

      expect(service_class.arguments_schema[:type]).to eq('object')
      expect(service_class.arguments_schema['type']).to eq('object')
    end

    it 'leaves other kinds untouched' do
      service_class.schema arguments: { type: 'object' }

      expect(service_class.result_schema).to be_nil
      expect(service_class.failure_schema).to be_nil
    end

    it 'preserves an earlier declaration when a keyword is omitted' do
      service_class.schema arguments: { type: 'object' }
      service_class.schema result: { type: 'array' }

      expect(service_class.arguments_schema['type']).to eq('object')
      expect(service_class.result_schema['type']).to eq('array')
    end

    it 'replaces an earlier declaration of the same kind' do
      service_class.schema arguments: { type: 'object' }
      service_class.schema arguments: { type: 'array' }

      expect(service_class.arguments_schema['type']).to eq('array')
    end

    # A nil here is almost always a lookup that failed. Accepting it would
    # leave the class validating nothing, with nothing to indicate that.
    it 'raises on an explicit nil rather than silently declaring nothing' do
      expect { service_class.schema arguments: nil }
        .to raise_error(ArgumentError, /declared a nil arguments schema/)
    end

    it 'raises on an unknown schema kind' do
      expect { service_class.schema argument: { type: 'object' } }
        .to raise_error(ArgumentError, /unknown schema kind :argument/)
    end

    it 'lists the valid kinds when rejecting an unknown one' do
      expect { service_class.schema payload: { type: 'object' } }
        .to raise_error(ArgumentError, /Valid: :arguments, :result, :failure/)
    end

    it 'reports every unknown kind at once' do
      expect { service_class.schema foo: {}, bar: {} }
        .to raise_error(ArgumentError, /unknown schema kinds :foo, :bar/)
    end
  end

  describe 'compiled readers' do
    before do
      Servus::Schema.register('core', { '$defs' => { 'amount' => { 'type' => 'integer' } } })
      service_class.schema arguments: {
        type: 'object',
        properties: { fee: { '$ref' => '#/core/$defs/amount' } }
      }
    end

    it 'resolves refs' do
      expect(service_class.arguments_schema.dig('properties', 'fee')).to eq({ 'type' => 'integer' })
    end

    it 'memoizes the compiled result' do
      first = service_class.arguments_schema

      expect(service_class.arguments_schema).to equal(first)
    end

    it 'recompiles when a referenced fragment changes' do
      service_class.arguments_schema

      Servus::Schema.register('core', { '$defs' => { 'amount' => { 'type' => 'number' } } })

      expect(service_class.arguments_schema.dig('properties', 'fee')).to eq({ 'type' => 'number' })
    end

    it 'recompiles when the schema is redeclared' do
      service_class.arguments_schema

      service_class.schema arguments: { type: 'array' }

      expect(service_class.arguments_schema['type']).to eq('array')
    end
  end

  describe 'raw readers' do
    before do
      Servus::Schema.register('core', { '$defs' => { 'amount' => { 'type' => 'integer' } } })
      service_class.schema arguments: { properties: { fee: { '$ref' => '#/core/$defs/amount' } } }
    end

    it 'returns the schema as authored, with refs intact' do
      expect(service_class.raw_arguments_schema.dig('properties', 'fee'))
        .to eq({ '$ref' => '#/core/$defs/amount' })
    end
  end

  describe 'inheritance' do
    let(:parent) do
      stub_const('DeclarationTest::Parent', Class.new(Servus::Base)).tap do |klass|
        klass.schema arguments: { type: 'object', required: ['name'] }
      end
    end

    let(:child) { stub_const('DeclarationTest::Child', Class.new(parent)) }

    # Without this a subclass silently validates nothing, which is the exact
    # failure this subsystem exists to prevent.
    it 'inherits a parent schema' do
      expect(child.arguments_schema['required']).to eq(['name'])
    end

    it 'lets a child override without affecting the parent' do
      child.schema arguments: { type: 'object', required: ['email'] }

      expect(child.arguments_schema['required']).to eq(['email'])
      expect(parent.arguments_schema['required']).to eq(['name'])
    end

    it 'inherits through the raw reader too' do
      expect(child.raw_arguments_schema['required']).to eq(['name'])
    end

    it 'returns nil when no ancestor declares one' do
      expect(child.result_schema).to be_nil
    end
  end

  describe 'events' do
    let(:event_class) { stub_const('DeclarationTest::Event', Class.new(Servus::Event)) }

    it 'declares only a payload kind' do
      expect { event_class.schema arguments: { type: 'object' } }
        .to raise_error(ArgumentError, /Valid: :payload/)
    end

    it 'compiles the payload schema' do
      Servus::Schema.register('core', { '$defs' => { 'id' => { 'type' => 'integer' } } })
      event_class.schema payload: { properties: { id: { '$ref' => '#/core/$defs/id' } } }

      expect(event_class.payload_schema.dig('properties', 'id')).to eq({ 'type' => 'integer' })
    end

    it 'raises on an explicit nil payload' do
      expect { event_class.schema payload: nil }
        .to raise_error(ArgumentError, /declared a nil payload schema/)
    end
  end
end
