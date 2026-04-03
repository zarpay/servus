# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Servus::Support::DataObject do
  # Fake model class simulating an ActiveRecord-like object
  class FakeUser
    attr_reader :id, :email, :name

    def initialize(id:, email:, name:)
      @id = id
      @email = email
      @name = name
    end
  end

  describe '.wrap' do
    it 'returns a DataObject for a Hash' do
      result = described_class.wrap({ key: 'value' })
      expect(result).to be_a(described_class)
    end

    it 'returns nil for nil' do
      expect(described_class.wrap(nil)).to be_nil
    end

    it 'returns a String unchanged' do
      expect(described_class.wrap('hello')).to eq('hello')
    end

    it 'returns an Integer unchanged' do
      expect(described_class.wrap(42)).to eq(42)
    end

    it 'returns an Array with Hash elements wrapped' do
      arr = [{ name: 'Alice' }, 'plain']
      result = described_class.wrap(arr)
      expect(result).to be_a(Array)
      expect(result.first).to be_a(described_class)
      expect(result.last).to eq('plain')
    end

    it 'returns a simple Array unchanged' do
      result = described_class.wrap([1, 2, 3])
      expect(result).to eq([1, 2, 3])
    end
  end

  describe 'bracket access' do
    let(:data) { described_class.wrap({ user: 'Alice', 'role' => 'admin' }) }

    it 'accesses symbol keys' do
      expect(data[:user]).to eq('Alice')
    end

    it 'accesses string keys' do
      expect(data['role']).to eq('admin')
    end
  end

  describe 'accessor access' do
    let(:data) { described_class.wrap({ user: 'Alice', 'role' => 'admin' }) }

    it 'accesses symbol keys as methods' do
      expect(data.user).to eq('Alice')
    end

    it 'accesses string keys as methods' do
      expect(data.role).to eq('admin')
    end

    it 'raises NoMethodError for missing keys' do
      expect { data.nonexistent }.to raise_error(NoMethodError)
    end

    it 'returns true from respond_to? for existing keys' do
      expect(data.respond_to?(:user)).to be true
    end

    it 'returns false from respond_to? for missing keys' do
      expect(data.respond_to?(:nonexistent)).to be false
    end
  end

  describe 'deeply nested hash structures' do
    it 'wraps two levels deep' do
      data = described_class.wrap({ user: { email: 'a@b.com', name: 'Alice' } })

      expect(data.user).to be_a(described_class)
      expect(data.user.email).to eq('a@b.com')
      expect(data.user.name).to eq('Alice')
    end

    it 'wraps three levels deep' do
      data = described_class.wrap({
                                    user: {
                                      address: {
                                        city: 'Berlin'
                                      }
                                    }
                                  })

      expect(data.user.address.city).to eq('Berlin')
    end

    it 'wraps four levels deep' do
      data = described_class.wrap({
                                    settings: {
                                      notifications: {
                                        channels: {
                                          email_enabled: true
                                        }
                                      }
                                    }
                                  })

      expect(data.settings.notifications.channels.email_enabled).to be true
    end

    it 'wraps Hashes inside Arrays' do
      data = described_class.wrap({
                                    order: {
                                      line_items: [
                                        { sku: 'A1', qty: 2 },
                                        { sku: 'B2', qty: 1 }
                                      ]
                                    }
                                  })

      expect(data.order.line_items).to be_a(Array)
      expect(data.order.line_items.first).to be_a(described_class)
      expect(data.order.line_items.first.sku).to eq('A1')
      expect(data.order.line_items.last.qty).to eq(1)
    end
  end

  describe 'arrays of objects' do
    it 'wraps Hash elements inside Arrays as DataObjects' do
      data = described_class.wrap({ users: [{ name: 'Alice' }, { name: 'Bob' }] })

      expect(data.users).to be_a(Array)
      expect(data.users.length).to eq(2)
      expect(data.users.first).to be_a(described_class)
      expect(data.users.first.name).to eq('Alice')
      expect(data.users.last.name).to eq('Bob')
    end

    it 'leaves non-Hash Array elements unchanged' do
      data = described_class.wrap({ tags: %w[ruby rails] })

      expect(data.tags).to eq(%w[ruby rails])
    end
  end

  describe 'non-Hash object values' do
    let(:user) { FakeUser.new(id: 1, email: 'alice@example.com', name: 'Alice') }

    it 'returns model instances directly without wrapping' do
      data = described_class.wrap({ user: user })

      expect(data.user).to equal(user)
      expect(data.user).to be_a(FakeUser)
    end

    it 'allows chaining through model methods' do
      data = described_class.wrap({ user: user })

      expect(data.user.email).to eq('alice@example.com')
      expect(data.user.name).to eq('Alice')
    end

    it 'returns an Array of model instances' do
      users = [
        FakeUser.new(id: 1, email: 'a@b.com', name: 'Alice'),
        FakeUser.new(id: 2, email: 'b@c.com', name: 'Bob')
      ]
      data = described_class.wrap({ users: users })

      expect(data.users).to be_a(Array)
      expect(data.users.first).to be_a(FakeUser)
      expect(data.users.first.email).to eq('a@b.com')
    end

    it 'handles mixed Hash and model values' do
      data = described_class.wrap({
                                    user: user,
                                    metadata: { source: 'api', version: 2 }
                                  })

      expect(data.user).to be_a(FakeUser)
      expect(data.user.email).to eq('alice@example.com')
      expect(data.metadata).to be_a(described_class)
      expect(data.metadata.source).to eq('api')
    end
  end

  describe 'mixed complex structure' do
    let(:user) { FakeUser.new(id: 1, email: 'alice@example.com', name: 'Alice') }
    let(:now) { Time.now }
    let(:data) do
      described_class.wrap({
                             user: user,
                             order: {
                               id: 'ORD-123',
                               total: 99.99,
                               items: [
                                 { sku: 'A1', qty: 2 },
                                 { sku: 'B2', qty: 1 }
                               ],
                               shipping: {
                                 address: { city: 'Berlin', zip: '10115' },
                                 method: 'express'
                               }
                             },
                             tags: %w[vip eu],
                             processed_at: now
                           })
    end

    it 'returns model instance for user' do
      expect(data.user).to equal(user)
    end

    it 'chains through model methods' do
      expect(data.user.email).to eq('alice@example.com')
    end

    it 'accesses nested hash values' do
      expect(data.order.id).to eq('ORD-123')
      expect(data.order.total).to eq(99.99)
    end

    it 'wraps Hash elements inside Array items' do
      expect(data.order.items).to be_a(Array)
      expect(data.order.items.first).to be_a(described_class)
      expect(data.order.items.first.sku).to eq('A1')
    end

    it 'accesses deeply nested hash values' do
      expect(data.order.shipping.address.city).to eq('Berlin')
      expect(data.order.shipping.address.zip).to eq('10115')
    end

    it 'returns plain Array for tags' do
      expect(data.tags).to eq(%w[vip eu])
    end

    it 'returns Time instance unchanged' do
      expect(data.processed_at).to equal(now)
    end

    it 'supports bracket access alongside accessor access' do
      expect(data[:user]).to equal(user)
      expect(data[:order][:shipping]).to be_a(Hash)
    end
  end

  describe 'hash delegation' do
    let(:data) { described_class.wrap({ a: 1, b: 2, c: 3 }) }

    it 'delegates keys' do
      expect(data.keys).to eq(%i[a b c])
    end

    it 'delegates values' do
      expect(data.values).to eq([1, 2, 3])
    end

    it 'delegates each' do
      collected = data.map { |k, v| [k, v] }
      expect(collected).to eq([[:a, 1], [:b, 2], [:c, 3]])
    end

    it 'delegates any?' do
      expect(data.any?).to be true
    end

    it 'delegates empty?' do
      expect(data.empty?).to be false
      expect(described_class.wrap({}).empty?).to be true
    end

    it 'delegates size and length' do
      expect(data.size).to eq(3)
      expect(data.length).to eq(3)
    end

    it 'delegates as_json' do
      result = data.as_json
      expect(result).to be_a(Hash)
      expect(result).to eq({ 'a' => 1, 'b' => 2, 'c' => 3 })
    end

    it 'delegates to_json' do
      parsed = JSON.parse(data.to_json)
      expect(parsed).to eq({ 'a' => 1, 'b' => 2, 'c' => 3 })
    end

    it 'equals a plain Hash with ==' do
      expect(data).to eq({ a: 1, b: 2, c: 3 })
    end

    it 'delegates merge and returns a plain Hash' do
      result = data.merge(d: 4)
      expect(result).to be_a(Hash)
      expect(result).not_to be_a(described_class)
    end
  end

  describe 'read-only enforcement' do
    let(:data) { described_class.wrap({ existing: 'value' }) }

    it 'does not allow setting new keys via accessor' do
      expect { data.new_key = 'value' }.to raise_error(NoMethodError)
    end
  end

  describe 'schema validation integration' do
    module DataObjectTest
      class ValidResultService < Servus::Base
        schema(
          result: {
            type: 'object',
            required: %w[name age],
            properties: {
              name: { type: 'string' },
              age: { type: 'integer' }
            }
          }
        )

        def initialize(name:, age:)
          @name = name
          @age = age
        end

        def call
          success({ name: @name, age: @age })
        end
      end

      class ValidFailureService < Servus::Base
        schema(
          failure: {
            type: 'object',
            required: %w[reason],
            properties: {
              reason: { type: 'string' }
            }
          }
        )

        def call
          failure('Something failed', data: { reason: 'invalid_input' })
        end
      end

      class InvalidResultService < Servus::Base
        schema(
          result: {
            type: 'object',
            required: %w[name],
            properties: {
              name: { type: 'string' }
            }
          }
        )

        def call
          success({ name: 123 })
        end
      end

      class NestedSchemaService < Servus::Base
        schema(
          result: {
            type: 'object',
            required: %w[user],
            properties: {
              user: {
                type: 'object',
                required: %w[name],
                properties: {
                  name: { type: 'string' }
                }
              }
            }
          }
        )

        def call
          success({ user: { name: 123 } })
        end
      end

      class OrderService < Servus::Base
        schema(
          result: {
            type: 'object',
            required: %w[order],
            properties: {
              order: {
                type: 'object',
                required: %w[id total],
                properties: {
                  id: { type: 'string' },
                  total: { type: 'number' }
                }
              }
            }
          }
        )

        def call
          success({ order: { id: 'ORD-1', total: 49.99 } })
        end
      end
    end

    before { Servus::Support::Validator.clear_cache! }

    it 'validates DataObject-wrapped result data against schema' do
      result = DataObjectTest::ValidResultService.call(name: 'Alice', age: 30)

      expect(result).to be_success
      expect(result.data).to be_a(described_class)
      expect(result.data.name).to eq('Alice')
    end

    it 'validates DataObject-wrapped failure data against failure schema' do
      result = DataObjectTest::ValidFailureService.call

      expect(result).to be_failure
      expect(result.data).to be_a(described_class)
      expect(result.data.reason).to eq('invalid_input')
    end

    it 'raises ValidationError for invalid DataObject-wrapped data' do
      expect { DataObjectTest::InvalidResultService.call }.to raise_error(
        Servus::Support::Errors::ValidationError,
        /did not match the following type: string/
      )
    end

    it 'validates nested object schemas through DataObject' do
      expect { DataObjectTest::NestedSchemaService.call }.to raise_error(
        Servus::Support::Errors::ValidationError,
        /did not match the following type: string/
      )
    end

    it 'passes validation and supports accessor access on validated result' do
      result = DataObjectTest::OrderService.call

      expect(result).to be_success
      expect(result.data.order.id).to eq('ORD-1')
      expect(result.data.order.total).to eq(49.99)
    end
  end
end
