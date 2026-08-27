# frozen_string_literal: true

require "rails_helper"

# =============================================================================
# Servus's RSpec matchers and example builders — every form
# =============================================================================
#
# Features exercised:
#   - be_service_success
#   - be_service_failure, with a class and with .with_message
#   - be_guard_failure, with a code and with .with_message
#   - have_schema for all four kinds
#   - emit_event, with .with
#   - call_service, with .with and .async
#   - servus_arguments_example / servus_result_example / servus_failure_example
#   - servus_success_response / servus_failure_response
#
# -----------------------------------------------------------------------------
# Where they come from
# -----------------------------------------------------------------------------
#
# `require "servus/testing"` in rails_helper loads all of them. The matchers
# self-register on RSpec::Matchers, so they need no `config.include`. The
# example builders DO need including — see rails_helper.
RSpec.describe "Servus test helpers" do
  let(:house) { create(:house) }
  let(:from_vault) { create(:vault, house: house, gold_dragons: 1_000) }
  let(:to_vault) { create(:vault, gold_dragons: 0) }

  def transfer(amount)
    Treasury::TransferGold::Service.call(
      from_vault_id: from_vault.id, to_vault_id: to_vault.id, gold_dragons: amount
    )
  end

  describe "be_service_success" do
    it "passes for a successful Response" do
      expect(transfer(10)).to be_service_success
    end

    it "fails for a failure" do
      expect(transfer(99_999)).not_to be_service_success
    end
  end

  describe "be_service_failure" do
    it "passes for any failure when given no arguments" do
      expect(transfer(99_999)).to be_service_failure
    end

    # Narrowed to an error class, which is how you assert that the RIGHT kind
    # of failure happened rather than just that something went wrong.
    it "narrows to an error class" do
      result = Treasury::TransferGold::Service.call(
        from_vault_id: 999_999, to_vault_id: to_vault.id, gold_dragons: 1
      )

      expect(result).to be_service_failure(Servus::Support::Errors::NotFoundError)
    end

    it "does not match a different error class" do
      result = Treasury::TransferGold::Service.call(
        from_vault_id: 999_999, to_vault_id: to_vault.id, gold_dragons: 1
      )

      expect(result).not_to be_service_failure(Servus::Support::Errors::ConflictError)
    end

    # `.with_message` is exact equality, not a substring match.
    it "chains an exact message" do
      create(:vault, house: house, sealed: true)
      result = Citadel::ConsultRecords::Service.call(house_id: house.id)

      expect(result)
        .to be_service_failure(Servus::Support::Errors::ConflictError)
        .with_message("The vault is sealed; records cannot be consulted")
    end
  end

  describe "be_guard_failure" do
    it "passes for any guard failure" do
      expect(transfer(99_999)).to be_guard_failure
    end

    # Narrowed by the guard's error_code — the stable, machine-readable
    # identifier, rather than its human message.
    it "narrows to a guard's error code" do
      expect(transfer(99_999)).to be_guard_failure("insufficient_gold")
    end

    it "does not match a different code" do
      expect(transfer(99_999)).not_to be_guard_failure("invalid_state")
    end

    it "chains an exact message" do
      expect(transfer(99_999))
        .to be_guard_failure("insufficient_gold")
        .with_message("Vault holds 1000 dragons, needs 99999")
    end

    # A guard failure IS a service failure, but the reverse is not true.
    it "is distinct from an ordinary service failure" do
      not_found = Treasury::TransferGold::Service.call(
        from_vault_id: 999_999, to_vault_id: to_vault.id, gold_dragons: 1
      )

      expect(not_found).to be_service_failure
      expect(not_found).not_to be_guard_failure
    end
  end

  describe "have_schema" do
    it "checks each schema kind on a service" do
      expect(Treasury::TransferGold::Service).to have_schema(:arguments)
      expect(Treasury::TransferGold::Service).to have_schema(:result)
      expect(Treasury::TransferGold::Service).to have_schema(:failure)
    end

    it "checks the payload kind on an event" do
      expect(GoldTransferredEvent).to have_schema(:payload)
    end

    it "reports a kind that is not declared" do
      expect(Citadel::ConsultRecords::Service).not_to have_schema(:result)
    end

    # The matcher compiles the schema, so a broken $ref fails here rather than
    # at the first call in production. That makes it a useful CI guard.
    it "surfaces a broken ref rather than passing" do
      broken = stub_const("BrokenRefService", Class.new(Servus::Base) do
        schema arguments: { "$ref" => "#/nonexistent/$defs/thing" }
      end)

      expect { expect(broken).to have_schema(:arguments) }
        .to raise_error(Servus::Schema::UnknownKeyError)
    end
  end

  describe "emit_event" do
    it "passes when the event is emitted" do
      expect { transfer(10) }.to emit_event(:gold_transferred_event)
    end

    it "accepts an Event class as well as a symbol" do
      expect { transfer(10) }.to emit_event(GoldTransferredEvent)
    end

    it "chains a payload matcher" do
      expect { transfer(10) }
        .to emit_event(:gold_transferred_event)
        .with(hash_including(transferred: 10))
    end

    it "negates" do
      expect { transfer(10) }.not_to emit_event(:large_transfer_event)
    end
  end

  describe "call_service" do
    # Asserts that a service was invoked — and stubs it out in the process, so
    # the real service does not run.
    it "asserts a service was called" do
      expect { RavenRequestedEvent.handle(house_id: house.id, message: "x") }
        .to call_service(Ravens::DispatchMessage::Service).async
    end

    # A sharp edge worth knowing: `.with` on an async call must include the
    # SCHEDULING options too, not just the service's arguments. The enqueue
    # declaration adds `queue: :ravens`, and Servus passes it through to
    # call_async — so the actual call is the payload merged with the schedule.
    it "chains expected arguments, including the scheduling options" do
      expect { RavenRequestedEvent.handle(house_id: house.id, message: "x") }
        .to call_service(Ravens::DispatchMessage::Service)
        .async
        .with(house_id: house.id, message: "x", queue: :ravens)
    end

    # Without `.async` the matcher expects a synchronous `.call`. Since Servus
    # 1.0 an Event class never makes one, so the plain form is for direct
    # service-to-service calls.
    #
    # Note the outer service still returns its OWN Response. That matters: the
    # matcher stubs the inner service, so `Citadel::ConsultRecords::Service.call`
    # returns nil here. A service whose `call` returns nil rather than a
    # Response fails deep inside Servus's logger with
    # `undefined method \'success?\' for nil` — an error that blames the logger
    # rather than the service that forgot to return.
    it "expects a synchronous call without .async" do
      caller_service = stub_const("CallerService", Class.new(ApplicationService) do
        schema arguments: { type: "object" }

        def initialize(**) = nil

        def call
          Citadel::ConsultRecords::Service.call(house_id: 1)
          success(delegated: true)
        end
      end)

      expect { caller_service.call }.to call_service(Citadel::ConsultRecords::Service)
    end
  end

  describe "example builders" do
    # These read the `example:` keys out of a service's own schema, so a
    # fixture cannot drift from the contract — change the schema and the
    # fixture follows.
    it "builds arguments from the schema's examples" do
      args = servus_arguments_example(Treasury::TransferGold::Service)

      expect(args).to include(from_vault_id: 1, to_vault_id: 2, gold_dragons: 50)
    end

    it "accepts overrides" do
      args = servus_arguments_example(Treasury::TransferGold::Service, gold_dragons: 999)

      expect(args[:gold_dragons]).to eq(999)
      expect(args[:from_vault_id]).to eq(1)
    end

    # Useful for stubbing a collaborator: a Response shaped exactly like the
    # real thing, without running it.
    it "builds a success Response from the result schema" do
      result = servus_result_example(Treasury::TransferGold::Service)

      expect(result).to be_service_success
      expect(result.data.transferred).to eq(50)
    end

    it "builds a failure Response from the failure schema" do
      result = servus_failure_example(Treasury::TransferGold::Service)

      expect(result).to be_service_failure
      expect(result.data.reason).to eq("insufficient_gold")
    end

    it "builds bare responses without a schema" do
      expect(servus_success_response(id: 1)).to be_service_success
      expect(servus_failure_response("nope")).to be_service_failure
    end
  end
end
