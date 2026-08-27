# frozen_string_literal: true

require "rails_helper"

# =============================================================================
# Emitting events from a service — the `emits` DSL
# =============================================================================
#
# Features exercised:
#   - emits on :success, :failure, and :error!
#   - Default payloads per trigger
#   - Block and `with:` payload builders
#   - Conditional emission via if:
#   - Multiple events on one trigger
#   - The emit_event matcher, with and without .with
RSpec.describe "emitting events" do
  let(:from_house) { create(:house) }
  let(:from_vault) { create(:vault, house: from_house, gold_dragons: 1_000) }
  let(:to_vault) { create(:vault, gold_dragons: 0) }

  def transfer(amount)
    Treasury::TransferGold::Service.call(
      from_vault_id: from_vault.id, to_vault_id: to_vault.id, gold_dragons: amount
    )
  end

  describe "the :success trigger" do
    it "emits the event whose payload defaults to result.data" do
      expect { transfer(100) }.to emit_event(:gold_transferred_event)
    end

    it "carries the result data as the payload" do
      expect { transfer(100) }
        .to emit_event(:gold_transferred_event)
        .with(hash_including(transferred: 100, from_balance: 900, to_balance: 100))
    end

    # A trigger holds a list. All three declarations below are on :success, and
    # each gets its own payload — the default, a block, and a `with:` method.
    it "emits every event declared on the trigger, not just the first" do
      expect { transfer(100) }.to emit_event(:gold_transferred_event)
      expect { transfer(100) }.to emit_event(:vault_audited_event)
    end

    it "builds the second event's payload with its block" do
      expect { transfer(100) }
        .to emit_event(:vault_audited_event)
        .with(hash_including(vault_id: from_vault.id))
    end
  end

  describe "conditional emission" do
    # When the condition fails the event is skipped entirely — no payload is
    # built, no validation runs, nothing reaches the bus.
    it "skips the event when the condition is not met" do
      expect { transfer(100) }.not_to emit_event(:large_transfer_event)
    end

    it "emits it when the condition is met" do
      expect { transfer(500) }.to emit_event(:large_transfer_event)
    end
  end

  describe "the :failure trigger" do
    # The default failure payload is `result.error` — a ServiceError object,
    # not a Hash, which no object schema can validate. So this service builds
    # the payload with `with: :failure_payload`.
    it "emits on a guard failure" do
      expect { transfer(99_999) }.to emit_event(:transfer_failed_event)
    end

    it "carries the built payload rather than the raw error" do
      expect { transfer(99_999) }
        .to emit_event(:transfer_failed_event)
        .with(hash_including(reason: "insufficient_gold"))
    end

    it "does not emit the success events" do
      expect { transfer(99_999) }.not_to emit_event(:gold_transferred_event)
    end
  end

  describe "the :error! trigger" do
    # `error!` emits and then raises. Because the exception propagates out of
    # Servus::Base.call, the after-call path that emits :failure never runs —
    # so a service declaring both gets exactly one per call.
    it "emits before raising" do
      house = create(:house)

      expect do
        expect { Ravens::DispatchMessage::Service.call(
          house_id: house.id, message: "x", destination: "beyond_the_wall"
        ) }.to raise_error(Servus::Support::Errors::ServiceError)
      end.not_to raise_error
    end
  end

  describe "payload schema enforcement" do
    # config.require_event_payload_schema is true in this app, so emitting an
    # event whose payload does not match its Event class's schema raises.
    it "raises when a payload does not match the event's schema" do
      bad = stub_const("BadPayloadService", Class.new(ApplicationService) do
        schema arguments: { type: "object" }
        emits :gold_transferred_event, on: :success

        def initialize(**) = nil
        def call = success(transferred: "lots")
      end)

      expect { bad.call }.to raise_error(Servus::Support::Errors::ValidationError, /transferred/)
    end

    # And the case the flag exists for: an event name with no Event class at
    # all cannot be validated by anything, so it raises rather than passing
    # silently.
    it "raises when no Event class is registered for the name" do
      orphan = stub_const("OrphanEventService", Class.new(ApplicationService) do
        schema arguments: { type: "object" }
        emits :nothing_listens_to_this, on: :success

        def initialize(**) = nil
        def call = success(any: "data")
      end)

      expect { orphan.call }
        .to raise_error(Servus::Support::Errors::SchemaRequiredError, /no Event class is registered/)
    end
  end

  describe "introspection" do
    # Emissions are readable, which is how you would build a catalog page or
    # assert coverage in CI.
    it "lists what a service declares, grouped by trigger" do
      emissions = Treasury::TransferGold::Service.event_emissions

      expect(emissions[:success].map { _1[:event_name] })
        .to eq(%i[gold_transferred_event vault_audited_event large_transfer_event])
      expect(emissions[:failure].map { _1[:event_name] }).to eq([:transfer_failed_event])
      expect(emissions[:error!].map { _1[:event_name] }).to eq([:transfer_error_event])
    end
  end
end
