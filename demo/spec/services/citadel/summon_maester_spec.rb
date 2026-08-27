# frozen_string_literal: true

require "rails_helper"

# =============================================================================
# Citadel::SummonMaester::Service — the other lazily shapes
# =============================================================================
#
# Features exercised:
#   - lazily with `by:` a column other than the primary key
#   - lazily with an Array, resolving to a relation rather than an Array
#   - success(nil)
RSpec.describe Citadel::SummonMaester::Service do
  let!(:house) { create(:house, name: "House Tarly") }

  describe "resolving by a natural key" do
    # `by: :name` resolves through find_by! rather than find. Useful when the
    # caller knows a name — a webhook, a CLI — rather than a database id.
    it "finds the record by the named column" do
      expect(described_class.call(house: "House Tarly")).to be_service_success
      expect(Raven.last.house).to eq(house)
    end

    it "reports an unknown key as a NotFoundError failure" do
      result = described_class.call(house: "House Nobody")

      expect(result).to be_service_failure(Servus::Support::Errors::NotFoundError)
    end
  end

  describe "resolving an Array" do
    let!(:witnesses) { create_list(:house, 2) }

    # An Array resolves to `House.where(id: [...])` — a relation, not an Array.
    it "resolves to a relation" do
      described_class.call(house: house.name, witnesses: witnesses.map(&:id))

      expect(Raven.last.message).to include("before 2 witness(es)")
    end

    # The plural form does NOT raise for ids that are not there — a missing id
    # is simply absent from the relation. That is the opposite of the singular
    # form, and the difference is easy to be surprised by.
    it "silently omits ids that do not exist, rather than raising" do
      result = described_class.call(house: house.name, witnesses: [witnesses.first.id, 999_999])

      expect(result).to be_service_success
      expect(Raven.last.message).to include("before 1 witness(es)")
    end
  end

  describe "success(nil)" do
    subject(:result) { described_class.call(house: house.name) }

    # A service that acts but has nothing to return. Still a success; `data` is
    # just nil.
    it "is still a success" do
      expect(result).to be_service_success
      expect(result).to be_success
    end

    it "has nil data" do
      expect(result.data).to be_nil
    end

    it "did the work regardless" do
      expect { result }.to change(Raven, :count).by(1)
    end
  end
end
