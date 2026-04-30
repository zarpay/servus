# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Servus::Testing::ExampleExtractor do
  # Test service classes
  module ExampleExtractionTest
    class SimpleService < Servus::Base
      def initialize(name:)
        @name = name
      end

      def call
        success({ id: 1, name: @name })
      end
    end

    class NestedService < Servus::Base
      def initialize(user:)
        @user = user
      end

      def call
        success({ user: @user })
      end
    end

    class ArrayService < Servus::Base
      def initialize(items:)
        @items = items
      end

      def call
        success({ items: @items })
      end
    end
  end

  before { Servus::Support::Validator.clear_cache! }

  describe '.extract' do
    context 'with no schema defined' do
      it 'returns empty hash when no schema exists' do
        result = described_class.extract(ExampleExtractionTest::SimpleService, :arguments)
        expect(result).to eq({})
      end

      it 'returns empty hash when schema has no properties' do
        ExampleExtractionTest::SimpleService.schema(
          arguments: { type: 'object' }
        )

        result = described_class.extract(ExampleExtractionTest::SimpleService, :arguments)
        expect(result).to eq({})
      end
    end

    context 'with simple properties using example keyword (singular)' do
      before do
        ExampleExtractionTest::SimpleService.schema(
          arguments: {
            type: 'object',
            properties: {
              name: { type: 'string', example: 'John Doe' },
              age: { type: 'integer', example: 30 },
              active: { type: 'boolean', example: true }
            }
          }
        )
      end

      it 'extracts example values from all properties' do
        result = described_class.extract(ExampleExtractionTest::SimpleService, :arguments)

        expect(result).to eq({
                               name: 'John Doe',
                               age: 30,
                               active: true
                             })
      end

      it 'returns symbolized keys' do
        result = described_class.extract(ExampleExtractionTest::SimpleService, :arguments)
        expect(result.keys).to all(be_a(Symbol))
      end
    end

    context 'with simple properties using examples keyword (plural)' do
      before do
        ExampleExtractionTest::SimpleService.schema(
          arguments: {
            type: 'object',
            properties: {
              name: { type: 'string', examples: ['John Doe', 'Jane Smith'] },
              age: { type: 'integer', examples: [30, 25, 40] },
              active: { type: 'boolean', examples: [true, false] }
            }
          }
        )
      end

      it 'extracts any example value from examples array' do
        result = described_class.extract(ExampleExtractionTest::SimpleService, :arguments)

        expect(['John Doe', 'Jane Smith']).to include(result[:name])
        expect([30, 25, 40]).to include(result[:age])
        expect([true, false]).to include(result[:active])
      end

      it 'handles empty examples array' do
        ExampleExtractionTest::SimpleService.schema(
          arguments: {
            type: 'object',
            properties: {
              name: { type: 'string', examples: [] }
            }
          }
        )

        result = described_class.extract(ExampleExtractionTest::SimpleService, :arguments)
        expect(result).to eq({})
      end
    end

    context 'with mixed example and examples keywords' do
      before do
        ExampleExtractionTest::SimpleService.schema(
          arguments: {
            type: 'object',
            properties: {
              name: { type: 'string', example: 'John Doe' },
              age: { type: 'integer', examples: [30, 25] },
              email: { type: 'string' } # no example
            }
          }
        )
      end

      it 'extracts both example and examples (sample value)' do
        result = described_class.extract(ExampleExtractionTest::SimpleService, :arguments)

        expect(result[:name]).to eq('John Doe')
        expect([30, 25]).to include(result[:age])
      end

      it 'omits properties without examples' do
        result = described_class.extract(ExampleExtractionTest::SimpleService, :arguments)
        expect(result).not_to have_key(:email)
      end
    end

    context 'with nested object properties' do
      before do
        ExampleExtractionTest::NestedService.schema(
          arguments: {
            type: 'object',
            properties: {
              user: {
                type: 'object',
                properties: {
                  id: { type: 'integer', example: 123 },
                  name: { type: 'string', example: 'John Doe' },
                  profile: {
                    type: 'object',
                    properties: {
                      bio: { type: 'string', example: 'Software developer' },
                      location: { type: 'string', example: 'San Francisco' }
                    }
                  }
                }
              }
            }
          }
        )
      end

      it 'extracts examples from nested objects' do
        result = described_class.extract(ExampleExtractionTest::NestedService, :arguments)

        expect(result).to eq({
                               user: {
                                 id: 123,
                                 name: 'John Doe',
                                 profile: {
                                   bio: 'Software developer',
                                   location: 'San Francisco'
                                 }
                               }
                             })
      end
    end

    context 'with array properties' do
      before do
        ExampleExtractionTest::ArrayService.schema(
          arguments: {
            type: 'object',
            properties: {
              items: {
                type: 'array',
                items: { type: 'string' },
                example: %w[item1 item2 item3]
              }
            }
          }
        )
      end

      it 'extracts example array values' do
        result = described_class.extract(ExampleExtractionTest::ArrayService, :arguments)

        expect(result).to eq({
                               items: %w[item1 item2 item3]
                             })
      end
    end

    context 'with array of objects (array examples)' do
      before do
        ExampleExtractionTest::ArrayService.schema(
          arguments: {
            type: 'object',
            properties: {
              items: {
                type: 'array',
                items: {
                  type: 'object',
                  properties: {
                    id: { type: 'integer' },
                    name: { type: 'string' }
                  }
                },
                example: [
                  { id: 1, name: 'First' },
                  { id: 2, name: 'Second' }
                ]
              }
            }
          }
        )
      end

      it 'extracts array of object examples' do
        result = described_class.extract(ExampleExtractionTest::ArrayService, :arguments)

        expect(result).to eq({
                               items: [
                                 { id: 1, name: 'First' },
                                 { id: 2, name: 'Second' }
                               ]
                             })
      end
    end

    context 'with array of objects (object examples)' do
      before do
        ExampleExtractionTest::ArrayService.schema(
          arguments: {
            type: 'object',
            properties: {
              items: {
                type: 'array',
                items: {
                  type: 'object',
                  properties: {
                    id: {
                      type: 'integer',
                      examples: [1, 2]
                    },
                    name: {
                      type: 'string',
                      examples: ['John Doe', 'Jane Smith']
                    }
                  }
                }
              }
            }
          }
        )
      end

      it 'extracts array of object examples that meets the minimum' do
        result = described_class.extract(ExampleExtractionTest::ArrayService, :arguments)

        expect(result[:items]).to be_an(Array)
        expect(result[:items].length).to eq(1)
        expect([1, 2]).to include(result[:items].first[:id])
        expect(['John Doe', 'Jane Smith']).to include(result[:items].first[:name])
      end
    end

    context 'with result schema' do
      before do
        ExampleExtractionTest::SimpleService.schema(
          result: {
            type: 'object',
            properties: {
              id: { type: 'integer', example: 456 },
              name: { type: 'string', example: 'Result Name' },
              created_at: { type: 'string', example: '2025-01-01T00:00:00Z' }
            }
          }
        )
      end

      it 'extracts examples from result schema' do
        result = described_class.extract(ExampleExtractionTest::SimpleService, :result)

        expect(result).to eq({
                               id: 456,
                               name: 'Result Name',
                               created_at: '2025-01-01T00:00:00Z'
                             })
      end
    end

    context 'with complex real-world schema' do
      before do
        ExampleExtractionTest::NestedService.schema(
          arguments: {
            type: 'object',
            required: %w[user_id payment_details],
            properties: {
              user_id: { type: 'integer', example: 123 },
              amount: { type: 'number', example: 99.99 },
              currency: { type: 'string', example: 'USD' },
              payment_details: {
                type: 'object',
                properties: {
                  method: { type: 'string', example: 'credit_card' },
                  card: {
                    type: 'object',
                    properties: {
                      number: { type: 'string', example: '4111111111111111' },
                      cvv: { type: 'string', example: '123' },
                      exp_month: { type: 'integer', example: 12 },
                      exp_year: { type: 'integer', example: 2025 }
                    }
                  }
                }
              },
              metadata: {
                type: 'object',
                properties: {
                  order_id: { type: 'string', example: 'ORD-123' },
                  tags: {
                    type: 'array',
                    items: { type: 'string' },
                    example: %w[urgent vip]
                  }
                }
              }
            }
          }
        )
      end

      it 'extracts all nested examples correctly' do
        result = described_class.extract(ExampleExtractionTest::NestedService, :arguments)

        expect(result).to eq({
                               user_id: 123,
                               amount: 99.99,
                               currency: 'USD',
                               payment_details: {
                                 method: 'credit_card',
                                 card: {
                                   number: '4111111111111111',
                                   cvv: '123',
                                   exp_month: 12,
                                   exp_year: 2025
                                 }
                               },
                               metadata: {
                                 order_id: 'ORD-123',
                                 tags: %w[urgent vip]
                               }
                             })
      end
    end

    context 'with string keys vs symbol keys in schema' do
      it 'handles string keys in schema' do
        ExampleExtractionTest::SimpleService.schema(
          arguments: {
            'type' => 'object',
            'properties' => {
              'name' => { 'type' => 'string', 'example' => 'String Keys' }
            }
          }
        )

        result = described_class.extract(ExampleExtractionTest::SimpleService, :arguments)
        expect(result).to eq({ name: 'String Keys' })
      end

      it 'handles symbol keys in schema' do
        ExampleExtractionTest::SimpleService.schema(
          arguments: {
            type: 'object',
            properties: {
              name: { type: 'string', example: 'Symbol Keys' }
            }
          }
        )

        result = described_class.extract(ExampleExtractionTest::SimpleService, :arguments)
        expect(result).to eq({ name: 'Symbol Keys' })
      end
    end

    context 'edge cases' do
      it 'handles nil example value' do
        ExampleExtractionTest::SimpleService.schema(
          arguments: {
            type: 'object',
            properties: {
              nullable_field: { type: %w[string null], example: nil }
            }
          }
        )

        result = described_class.extract(ExampleExtractionTest::SimpleService, :arguments)
        expect(result).to eq({ nullable_field: nil })
      end

      it 'handles numeric zero as example' do
        ExampleExtractionTest::SimpleService.schema(
          arguments: {
            type: 'object',
            properties: {
              count: { type: 'integer', example: 0 }
            }
          }
        )

        result = described_class.extract(ExampleExtractionTest::SimpleService, :arguments)
        expect(result).to eq({ count: 0 })
      end

      it 'handles false boolean as example' do
        ExampleExtractionTest::SimpleService.schema(
          arguments: {
            type: 'object',
            properties: {
              enabled: { type: 'boolean', example: false }
            }
          }
        )

        result = described_class.extract(ExampleExtractionTest::SimpleService, :arguments)
        expect(result).to eq({ enabled: false })
      end

      it 'handles empty string as example' do
        ExampleExtractionTest::SimpleService.schema(
          arguments: {
            type: 'object',
            properties: {
              optional_text: { type: 'string', example: '' }
            }
          }
        )

        result = described_class.extract(ExampleExtractionTest::SimpleService, :arguments)
        expect(result).to eq({ optional_text: '' })
      end
    end
  end

  describe '#initialize' do
    it 'accepts a schema hash' do
      schema = { type: 'object', properties: {} }
      extractor = described_class.new(schema)
      expect(extractor).to be_a(described_class)
    end
  end

  describe '#extract' do
    context 'with invalid schema types' do
      it 'returns empty hash for nil schema' do
        extractor = described_class.new(nil)
        expect(extractor.extract).to eq({})
      end

      it 'returns empty hash for non-hash schema' do
        extractor = described_class.new('not a hash')
        expect(extractor.extract).to eq({})
      end

      it 'returns empty hash for array schema' do
        extractor = described_class.new([1, 2, 3])
        expect(extractor.extract).to eq({})
      end
    end
  end
end
