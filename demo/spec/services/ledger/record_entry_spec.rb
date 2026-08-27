# frozen_string_literal: true

require "rails_helper"

# =============================================================================
# Ledger::RecordEntry::Service — lazy resolvers and nested data
# =============================================================================
#
# Features exercised:
#   - lazily resolving an id into a record
#   - lazily passing an already-loaded record straight through
#   - Nested result data read back through DataObject
#   - A failure carrying structured data validated by the failure schema
RSpec.describe Ledger::RecordEntry::Service do
  let(:vault) { create(:vault) }

  describe "lazy resolution" do
    # The service declares `lazily :vault, finds: Vault`, so it accepts an id
    # and resolves it on first read inside `call`.
    it "resolves an id into the record" do
      result = described_class.call(vault: vault.id, direction: "debit", amount: 10)

      expect(result).to be_service_success
      expect(LedgerEntry.last.vault_id).to eq(vault.id)
    end

    # A caller that already holds the record should not pay for a second query.
    # The resolver returns an instance of the target class untouched.
    it "passes an already-loaded record through without querying" do
      expect(Vault).not_to receive(:find)

      result = described_class.call(vault: vault, direction: "credit", amount: 10)

      expect(result).to be_service_success
    end

    # Resolution happens inside `call`, i.e. after argument validation. That is
    # why the schema for `vault` is loose — it has to accept both an id and a
    # record, because it runs before the resolver does.
    it "reports a missing record as a NotFoundError failure" do
      result = described_class.call(vault: 999_999, direction: "debit", amount: 10)

      expect(result).to be_service_failure(Servus::Support::Errors::NotFoundError)
    end
  end

  describe "nested result data" do
    subject(:result) { described_class.call(vault: vault, direction: "debit", amount: 25) }

    # DataObject re-wraps nested hashes as they are read, so depth costs the
    # caller nothing.
    it "reads nested values as methods" do
      expect(result.data.entry.amount).to eq(25)
      expect(result.data.entry.direction).to eq("debit")
    end

    it "reads the same values by key" do
      expect(result.data[:entry][:amount]).to eq(25)
    end

    it "wraps a nested object built from a shared fragment" do
      expect(result.data.vault.name).to eq(vault.house.name)
      expect(result.data.vault.standing).to eq("loyal")
    end
  end

  describe "a failure with structured data" do
    # The service catches RecordInvalid itself rather than letting
    # ApplicationService's rescue_from handle it, because it wants to attach
    # data — which a bare `use:` mapping cannot do.
    #
    # Note the input chosen here. A bad `direction` would NOT reach this code:
    # the argument schema's enum rejects it before the service is constructed.
    # `amount: 0` is the interesting case — the shared `gold_dragons` fragment
    # allows zero, so the schema passes it, and the model's
    # `numericality: { other_than: 0 }` is what refuses it.
    #
    # That is the layering working as intended: schemas describe shape, models
    # enforce domain rules, and the service translates the latter into a
    # structured failure.
    subject(:result) { described_class.call(vault: vault, direction: "debit", amount: 0) }

    it "returns a failure rather than raising" do
      expect(result).to be_service_failure
    end

    it "carries data matching the inherited failure schema" do
      expect(result.data.reason).to eq("invalid_entry")
      expect(result.data.detail).to be_present
    end

    # Proof the failure schema is enforced: this shape omits the required
    # `reason`, so Servus raises rather than returning a malformed failure.
    it "rejects failure data that does not match the schema" do
      broken = stub_const("BrokenFailure", Class.new(described_class) do
        def call = failure("nope", data: { unexpected: true })
      end)

      expect { broken.call(vault: vault, direction: "debit", amount: 1) }
        .to raise_error(Servus::Support::Errors::ValidationError, /reason/)
    end

    # And the argument schema catching a bad direction first, which is what
    # made the example above need a different input.
    it "rejects a bad direction at the argument layer, before the service runs" do
      expect { described_class.call(vault: vault, direction: "sideways", amount: 10) }
        .to raise_error(Servus::Support::Errors::ValidationError, /direction/)
    end
  end
end
