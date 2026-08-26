# frozen_string_literal: true

RSpec.describe Servus::Schema::Ref do
  describe '.parse' do
    context 'with a whole-fragment ref' do
      subject(:ref) { described_class.parse('#/core') }

      it 'extracts the key' do
        expect(ref.key).to eq('core')
      end

      it 'has no segments' do
        expect(ref.segments).to be_empty
      end

      it 'keeps the original value' do
        expect(ref.value).to eq('#/core')
      end
    end

    context 'with a path ref' do
      subject(:ref) { described_class.parse('#/core/$defs/amount') }

      it 'extracts the key' do
        expect(ref.key).to eq('core')
      end

      it 'extracts the segments in order' do
        expect(ref.segments).to eq(['$defs', 'amount'])
      end
    end

    context 'with a namespaced key' do
      subject(:ref) { described_class.parse('#/models::trade/$defs/id') }

      it 'treats :: as part of the key' do
        expect(ref.key).to eq('models::trade')
        expect(ref.segments).to eq(['$defs', 'id'])
      end
    end

    it 'treats segments as literal keys rather than JSON Pointer tokens' do
      ref = described_class.parse('#/core/a~1b')

      expect(ref.segments).to eq(['a~1b'])
    end

    describe 'rejected forms' do
      it 'rejects a non-String value' do
        expect { described_class.parse(123) }
          .to raise_error(Servus::Schema::InvalidRefError, /must be a String/)
      end

      it 'rejects a ref that does not start with #/' do
        expect { described_class.parse('core/$defs/amount') }
          .to raise_error(Servus::Schema::InvalidRefError, /always take the form/)
      end

      it 'rejects a remote ref' do
        expect { described_class.parse('https://example.com/s.json') }
          .to raise_error(Servus::Schema::InvalidRefError, /Remote and file refs/)
      end

      it 'rejects a bare fragment marker' do
        expect { described_class.parse('#/') }
          .to raise_error(Servus::Schema::InvalidRefError, /names no schema fragment key/)
      end

      # Naming this form specifically is the point — parsed positionally it
      # would look like a request for a fragment registered under "$defs".
      it 'rejects a local ref and says so' do
        expect { described_class.parse('#/$defs/amount') }
          .to raise_error(Servus::Schema::InvalidRefError, /local ref/)
      end
    end
  end
end
