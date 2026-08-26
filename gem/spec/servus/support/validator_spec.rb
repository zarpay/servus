# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Servus::Support::Validator, :schema_registry do
  # A fresh class per example. Schemas live on the class, so sharing one across
  # examples lets a schema declared in one leak into the next.
  let(:service_class) do
    stub_const(
      'SchemaValidationTest::Service',
      Class.new(Servus::Base) do
        def initialize(name:, age:)
          @name = name
          @age = age
        end

        def call
          success({ id: 123, name: @name, age: @age })
        end
      end
    )
  end

  before { described_class.clear_cache! }

  describe '.load_schema' do
    it 'returns nil when no schema is declared' do
      expect(described_class.load_schema(service_class, 'arguments')).to be_nil
    end

    it 'returns the declared schema' do
      service_class.schema arguments: { type: 'object', required: ['name'] }

      schema = described_class.load_schema(service_class, 'arguments')

      expect(schema['type']).to eq('object')
      expect(schema['required']).to include('name')
    end

    it 'resolves $refs against the registry' do
      Servus::Schema.register('core', { '$defs' => { 'name' => { 'type' => 'string' } } })
      service_class.schema arguments: {
        type: 'object',
        properties: { name: { '$ref' => '#/core/$defs/name' } }
      }

      schema = described_class.load_schema(service_class, 'arguments')

      expect(schema.dig('properties', 'name')).to eq({ 'type' => 'string' })
    end

    it 'raises rather than skipping validation when a $ref cannot be resolved' do
      service_class.schema arguments: { '$ref' => '#/nope/$defs/thing' }

      expect { described_class.load_schema(service_class, 'arguments') }
        .to raise_error(Servus::Schema::UnknownKeyError)
    end

    it 'raises for an unknown schema type' do
      expect { described_class.load_schema(service_class, 'nonexistent') }
        .to raise_error(ArgumentError, /unknown schema type/)
    end

    it 'accepts a symbol type' do
      service_class.schema arguments: { type: 'object' }

      expect(described_class.load_schema(service_class, :arguments)).to be_a(Hash)
    end

    describe 'caching' do
      before { service_class.schema arguments: { type: 'object', required: ['name'] } }

      it 'serves later reads from the cache' do
        described_class.load_schema(service_class, 'arguments')
        service_class.schema arguments: { type: 'object', required: ['changed'] }

        expect(described_class.load_schema(service_class, 'arguments')['required']).to include('name')
      end

      it 'picks up changes after the cache is cleared' do
        described_class.load_schema(service_class, 'arguments')
        service_class.schema arguments: { type: 'object', required: ['changed'] }
        described_class.clear_cache!

        expect(described_class.load_schema(service_class, 'arguments')['required']).to include('changed')
      end

      # The cache used to be keyed by a file path derived from the class's
      # namespace, which dropped the final segment — so two services in the
      # same namespace silently shared a schema.
      it 'does not confuse two classes in the same namespace' do
        other = stub_const('SchemaValidationTest::Other', Class.new(Servus::Base))
        other.schema arguments: { type: 'object', required: ['other_field'] }

        expect(described_class.load_schema(service_class, 'arguments')['required']).to include('name')
        expect(described_class.load_schema(other, 'arguments')['required']).to include('other_field')
      end
    end
  end

  describe '.validate_arguments!' do
    before do
      service_class.schema arguments: {
        type: 'object',
        required: ['name'],
        properties: {
          name: { type: 'string' },
          age: { type: 'integer', minimum: 18 }
        }
      }
    end

    it 'returns true for valid arguments' do
      expect(described_class.validate_arguments!(service_class, { name: 'John', age: 25 })).to be(true)
    end

    it 'returns true when no schema is declared' do
      expect(described_class.validate_arguments!(stub_const('Bare::Service', Class.new(Servus::Base)), {}))
        .to be(true)
    end

    it 'raises for a missing required field' do
      expect { described_class.validate_arguments!(service_class, { age: 25 }) }
        .to raise_error(Servus::Base::ValidationError, /required property of 'name'/)
    end

    it 'raises for an invalid field type' do
      expect { described_class.validate_arguments!(service_class, { name: 'John', age: 'twenty' }) }
        .to raise_error(Servus::Base::ValidationError, /did not match the following type: integer/)
    end

    it 'raises for an out of range value' do
      expect { described_class.validate_arguments!(service_class, { name: 'John', age: 17 }) }
        .to raise_error(Servus::Base::ValidationError, /did not have a minimum value of 18/)
    end

    it 'names the service in the error' do
      expect { described_class.validate_arguments!(service_class, {}) }
        .to raise_error(Servus::Base::ValidationError, /Invalid arguments for SchemaValidationTest::Service/)
    end
  end

  describe '.validate_result!' do
    let(:success_result) { Servus::Support::Response.new(true, { id: 123 }, nil) }
    let(:error_result) { Servus::Support::Response.new(false, nil, 'Error') }

    before do
      service_class.schema result: {
        type: 'object',
        required: %w[id status],
        properties: { id: { type: 'integer' }, status: { type: 'string' } }
      }
    end

    it 'returns a valid success result unchanged' do
      valid = Servus::Support::Response.new(true, { id: 123, status: 'complete' }, nil)

      expect(described_class.validate_result!(service_class, valid)).to eq(valid)
    end

    it 'returns failure results without validating them' do
      expect(described_class.validate_result!(service_class, error_result)).to eq(error_result)
    end

    it 'raises when a success result is missing a required property' do
      expect { described_class.validate_result!(service_class, success_result) }
        .to raise_error(Servus::Base::ValidationError, /did not contain a required property of 'status'/)
    end

    it 'raises when a success result has the wrong type' do
      invalid = Servus::Support::Response.new(true, { id: '123', status: 'complete' }, nil)

      expect { described_class.validate_result!(service_class, invalid) }
        .to raise_error(Servus::Base::ValidationError, /did not match the following type: integer/)
    end
  end

  describe '.validate_result! with a failure schema' do
    let(:error) { Servus::Support::Errors::ServiceError.new('failed') }

    before do
      service_class.schema failure: {
        type: 'object',
        required: %w[reason],
        properties: { reason: { type: 'string' }, code: { type: 'integer' } }
      }
    end

    it 'validates failure data against the failure schema' do
      valid = Servus::Support::Response.new(false, { reason: 'declined' }, error)

      expect(described_class.validate_result!(service_class, valid)).to eq(valid)
    end

    it 'raises when failure data does not match' do
      invalid = Servus::Support::Response.new(false, { reason: 123 }, error)

      expect { described_class.validate_result!(service_class, invalid) }
        .to raise_error(Servus::Base::ValidationError, /Invalid failure structure/)
    end

    it 'skips failures that carry no data' do
      no_data = Servus::Support::Response.new(false, nil, error)

      expect(described_class.validate_result!(service_class, no_data)).to eq(no_data)
    end
  end

  describe 'integration with .call' do
    before do
      service_class.schema(
        arguments: {
          type: 'object',
          required: %w[name age],
          properties: { name: { type: 'string' }, age: { type: 'integer', minimum: 18 } }
        },
        result: {
          type: 'object',
          required: %w[id name age],
          properties: { id: { type: 'integer' }, name: { type: 'string' }, age: { type: 'integer' } }
        }
      )
    end

    it 'validates arguments before the call and the result after it' do
      result = service_class.call(name: 'John', age: 25)

      expect(result).to be_success
      expect(result.data[:id]).to eq(123)
    end

    it 'raises before the call for invalid arguments' do
      expect { service_class.call(name: 'John', age: 17) }
        .to raise_error(Servus::Base::ValidationError, /did not have a minimum value of 18/)
    end
  end

  describe '.clear_cache!' do
    it 'empties the cache' do
      service_class.schema arguments: { type: 'object' }
      described_class.load_schema(service_class, 'arguments')

      expect { described_class.clear_cache! }.to change { described_class.cache.size }.to(0)
    end
  end

  describe 'schema enforcement' do
    after do
      Servus.config.require_service_arguments_schema = false
      Servus.config.require_service_result_schema = false
    end

    describe 'require_service_arguments_schema' do
      it 'raises when enabled and no arguments schema is declared' do
        Servus.config.require_service_arguments_schema = true

        expect { described_class.validate_arguments!(service_class, { name: 'John' }) }
          .to raise_error(Servus::Support::Errors::SchemaRequiredError, /require_service_arguments_schema/)
      end

      it 'does not raise when disabled' do
        Servus.config.require_service_arguments_schema = false

        expect(described_class.validate_arguments!(service_class, { name: 'John' })).to be(true)
      end

      it 'does not raise when enabled and a schema is declared' do
        Servus.config.require_service_arguments_schema = true
        service_class.schema arguments: { type: 'object', properties: { name: { type: 'string' } } }

        expect(described_class.validate_arguments!(service_class, { name: 'John' })).to be(true)
      end
    end

    describe 'require_service_result_schema' do
      let(:success_result) { Servus::Support::Response.new(true, { id: 123 }, nil) }
      let(:failure_result) { Servus::Support::Response.new(false, nil, Servus::Support::Errors::ServiceError.new) }

      it 'raises when enabled and a success result has no schema' do
        Servus.config.require_service_result_schema = true

        expect { described_class.validate_result!(service_class, success_result) }
          .to raise_error(Servus::Support::Errors::SchemaRequiredError, /require_service_result_schema/)
      end

      it 'does not raise for failure responses even when enabled' do
        Servus.config.require_service_result_schema = true

        expect(described_class.validate_result!(service_class, failure_result)).to eq(failure_result)
      end

      it 'does not raise when disabled' do
        Servus.config.require_service_result_schema = false

        expect(described_class.validate_result!(service_class, success_result)).to eq(success_result)
      end

      it 'does not raise when enabled and a result schema is declared' do
        Servus.config.require_service_result_schema = true
        service_class.schema result: { type: 'object', properties: { id: { type: 'integer' } } }

        expect(described_class.validate_result!(service_class, success_result)).to eq(success_result)
      end
    end
  end
end
