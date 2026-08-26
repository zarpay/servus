# frozen_string_literal: true

RSpec.describe Servus::Schema::Path do
  let(:fragment) do
    {
      '$defs' => {
        'amount' => { 'type' => 'integer' },
        'timestamp' => { 'type' => 'string' }
      }
    }
  end

  describe '.walk' do
    it 'returns the fragment when the path is empty' do
      expect(described_class.walk(fragment, 'core', [])).to eq(fragment)
    end

    it 'returns the value at the path' do
      expect(described_class.walk(fragment, 'core', ['$defs', 'amount']))
        .to eq({ 'type' => 'integer' })
    end

    it 'treats segments as literal keys rather than JSON Pointer tokens' do
      escaped = { 'a~1b' => { 'type' => 'string' } }

      expect(described_class.walk(escaped, 'core', ['a~1b'])).to eq({ 'type' => 'string' })
    end

    it 'raises naming the missing segment and the fragment' do
      expect { described_class.walk(fragment, 'core', ['$defs', 'nope']) }
        .to raise_error(Servus::Schema::RefNotFoundError) { |error|
          expect(error.message).to include('"nope"')
          expect(error.message).to include('schema fragment "core"')
        }
    end

    it 'lists the keys available where the walk failed' do
      expect { described_class.walk(fragment, 'core', ['$defs', 'nope']) }
        .to raise_error(Servus::Schema::RefNotFoundError, /Available keys: "amount", "timestamp"/)
    end

    it 'reports the full path that was attempted' do
      expect { described_class.walk(fragment, 'core', ['$defs', 'nope']) }
        .to raise_error(Servus::Schema::RefNotFoundError, %r{\$defs/nope})
    end

    it 'explains when the walk runs into a value that is not a Hash' do
      expect { described_class.walk(fragment, 'core', ['$defs', 'amount', 'type', 'deeper']) }
        .to raise_error(Servus::Schema::RefNotFoundError, /not a Hash/)
    end
  end
end
