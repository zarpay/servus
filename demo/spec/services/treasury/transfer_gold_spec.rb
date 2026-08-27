# frozen_string_literal: true

require "rails_helper"

# =============================================================================
# Treasury::TransferGold::Service
# =============================================================================
#
# Features exercised:
#   - Argument and result schema validation, including $ref resolution
#   - Sibling-merge tightening a shared fragment at one call site
#   - Guards halting the service with structured failures
#   - rescue_from converting an exception into a failure Response
#   - Lockdown: .new and #call are unavailable
#   - The Response object and DataObject access
RSpec.describe Treasury::TransferGold::Service do
  let(:from_house) { create(:house) }
  let(:to_house) { create(:house) }
  let(:from_vault) { create(:vault, house: from_house, gold_dragons: 1_000) }
  let(:to_vault) { create(:vault, house: to_house, gold_dragons: 0) }

  def transfer(amount, from: from_vault, to: to_vault)
    described_class.call(from_vault_id: from.id, to_vault_id: to.id, gold_dragons: amount)
  end

  describe "a successful transfer" do
    subject(:result) { transfer(250) }

    it "returns a successful Response" do
      expect(result).to be_service_success
    end

    it "moves the gold" do
      result
      expect(from_vault.reload.gold_dragons).to eq(750)
      expect(to_vault.reload.gold_dragons).to eq(250)
    end

    # Result data is wrapped in a DataObject, so it reads as methods rather
    # than hash lookups. Both work — the hash form is still there underneath.
    it "exposes result data by method and by key" do
      expect(result.data.transferred).to eq(250)
      expect(result.data[:transferred]).to eq(250)
    end
  end

  describe "argument validation" do
    # The schema runs before the service is even constructed, which is what
    # lets `call` assume its inputs. A ValidationError is a caller bug, not a
    # business outcome — hence a raise rather than a failure Response.
    it "raises rather than failing when a required argument is missing" do
      expect { described_class.call(from_vault_id: from_vault.id, gold_dragons: 5) }
        .to raise_error(Servus::Support::Errors::ValidationError, /to_vault_id/)
    end

    it "raises when an argument is the wrong type" do
      expect { transfer("many") }
        .to raise_error(Servus::Support::Errors::ValidationError, /gold_dragons/)
    end

    # The shared `core` fragment allows zero. This service's schema overrides
    # `minimum` to 1 with a sibling key, because a transfer of nothing is
    # meaningless — without touching the shared definition.
    it "rejects zero, which the shared fragment would have allowed" do
      expect { transfer(0) }
        .to raise_error(Servus::Support::Errors::ValidationError, /gold_dragons/)
    end

    it "still allows zero for the shared fragment itself" do
      expect(Servus::Schema.resolve("core", "$defs", "gold_dragons")["minimum"]).to eq(0)
    end
  end

  describe "guards" do
    it "refuses to move gold for a rebellious house" do
      from_house.update!(standing: "rebellious")

      expect(transfer(10)).to be_guard_failure("invalid_state")
    end

    it "refuses to move gold out of a sealed vault" do
      from_vault.update!(sealed: true)

      expect(transfer(10)).to be_guard_failure("must_be_falsey")
    end

    it "refuses to move more gold than the vault holds" do
      expect(transfer(99_999)).to be_guard_failure("insufficient_gold")
    end

    it "leaves both balances untouched when a guard halts it" do
      expect { transfer(99_999) }.not_to change { from_vault.reload.gold_dragons }
    end
  end

  describe "rescue_from" do
    # Inherited from ApplicationService. Without it, the RecordNotFound raised
    # by `Vault.find` would escape and 500 the request.
    it "turns a missing record into a NotFoundError failure" do
      result = described_class.call(from_vault_id: 999_999, to_vault_id: to_vault.id, gold_dragons: 1)

      expect(result).to be_service_failure(Servus::Support::Errors::NotFoundError)
    end

    it "carries the 404 status through to the caller" do
      result = described_class.call(from_vault_id: 999_999, to_vault_id: to_vault.id, gold_dragons: 1)

      expect(result.error.http_status).to eq(:not_found)
    end
  end

  describe "lockdown" do
    # Both are private, so a caller cannot skip the lifecycle that runs
    # validation, guards, logging, and event emission. The gem makes bypassing
    # it impossible rather than merely discouraged.
    it "does not allow direct instantiation" do
      expect { described_class.new(from_vault_id: 1, to_vault_id: 2, gold_dragons: 3) }
        .to raise_error(NoMethodError)
    end
  end

  describe "its schemas" do
    it "declares all three kinds" do
      expect(described_class).to have_schema(:arguments)
      expect(described_class).to have_schema(:result)
      expect(described_class).to have_schema(:failure)
    end

    # The failure schema is not declared here — it comes from
    # ApplicationService. Servus schemas are inherited per kind.
    it "inherits its failure schema from the abstract base" do
      expect(described_class.failure_schema).to eq(ApplicationService.failure_schema)
    end

    # Refs are resolved when the schema is read, so what validation sees is a
    # self-contained document with no $ref left in it.
    it "resolves its refs" do
      expect(described_class.arguments_schema.to_s).not_to include("$ref")
      expect(described_class.arguments_schema.dig("properties", "from_vault_id", "type"))
        .to eq("integer")
    end
  end
end
