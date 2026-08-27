# frozen_string_literal: true

require "rails_helper"

# =============================================================================
# Event reactions — enqueue, routing, and async execution
# =============================================================================
#
# Features exercised:
#   - Event.emit and Event.handle
#   - enqueue with scheduling options and conditions
#   - The pass-through reaction form
#   - A custom router contributing invocations
#   - Invocation identity and deduplication
#   - Bus.subscribe_all
#   - The call_service matcher with .async
#
# -----------------------------------------------------------------------------
# Why every example here is about a JOB
# -----------------------------------------------------------------------------
#
# Since Servus 1.0 event reactions are always enqueued. So an assertion falls
# into one of two shapes, and the adapter has to match:
#
#   default (:test)     assert the job was ENQUEUED — on which queue, with
#                       what arguments, after what delay.
#
#   `:inline_jobs` tag  assert the EFFECT — a Raven row exists, a ledger entry
#                       was written. Without the tag these would always fail,
#                       because nothing runs the job.
RSpec.describe "event reactions" do
  let!(:house) { create(:house) }

  describe "emitting directly with Event.emit" do
    it "validates the payload and enqueues the reaction" do
      expect { RavenRequestedEvent.emit(house_id: house.id, message: "Winter is coming") }
        .to have_enqueued_job(Ravens::DispatchMessage::ServiceJob).on_queue("ravens")
    end

    it "rejects a payload that does not match the event's schema" do
      expect { RavenRequestedEvent.emit(house_id: house.id) }
        .to raise_error(Servus::Support::Errors::ValidationError, /message/)
    end

    # The pass-through form: no mapper block, so the payload IS the arguments.
    it "passes the whole payload through as the service's arguments" do
      expect { RavenRequestedEvent.emit(house_id: house.id, message: "Hold the door") }
        .to have_enqueued_job(Ravens::DispatchMessage::ServiceJob)
        .with(house_id: house.id, message: "Hold the door")
    end
  end

  describe "actually running the reaction", :inline_jobs do
    # With the inline adapter the job runs on enqueue, so the assertion can be
    # about the effect rather than the scheduling.
    it "dispatches a raven" do
      expect { RavenRequestedEvent.emit(house_id: house.id, message: "The king is dead") }
        .to change(Raven, :count).by(1)

      expect(Raven.last.message).to eq("The king is dead")
      expect(Raven.last.dispatched_at).to be_present
    end
  end

  describe "scheduling options" do
    let(:from_vault) { create(:vault, house: house, gold_dragons: 1_000) }
    let(:to_vault) { create(:vault, gold_dragons: 0) }

    def large_transfer
      Treasury::TransferGold::Service.call(
        from_vault_id: from_vault.id, to_vault_id: to_vault.id, gold_dragons: 600
      )
    end

    it "routes the reaction to its declared queue" do
      expect { large_transfer }
        .to have_enqueued_job(Ledger::RecordEntry::ServiceJob).on_queue("ledger")
    end

    # `wait:` on an enqueue declaration becomes an ActiveJob delay.
    it "applies the declared delay" do
      freeze_time do
        expect { large_transfer }
          .to have_enqueued_job(Ravens::DispatchMessage::ServiceJob)
          .at(1.minute.from_now)
      end
    end
  end

  describe "Event.handle" do
    # `handle` runs an event's reactions directly, skipping the Bus and its
    # instrumentation. Useful for testing one Event class in isolation.
    it "enqueues the reactions without going through the bus" do
      expect { RavenRequestedEvent.handle(house_id: house.id, message: "Direct") }
        .to have_enqueued_job(Ravens::DispatchMessage::ServiceJob)
    end

    # The call_service matcher asserts on the method rather than the job. Note
    # `.async` is required — an Event class never calls a service synchronously.
    it "is visible to the call_service matcher with .async" do
      expect { RavenRequestedEvent.handle(house_id: house.id, message: "Direct") }
        .to call_service(Ravens::DispatchMessage::Service).async
    end
  end

  describe "the custom router" do
    # RavenRosterRouter is registered alongside ClassRouter in the initializer.
    # It contributes reactions that no Event class declares — the rule lives in
    # the router because it is about who is watching, not what the event means.
    let!(:rebel) { create(:house, :rebellious) }
    let!(:rebel_vault) { create(:vault, house: rebel, gold_dragons: 1_000) }

    it "contributes a reaction the Event class does not declare" do
      expect { GoldTransferredEvent.emit(transferred: 10, from_balance: 1, to_balance: 2) }
        .not_to have_enqueued_job(Ravens::DispatchMessage::ServiceJob)

      expect do
        Servus::Events::Bus.emit(:gold_transferred_event,
                                 { transferred: 10, from_balance: 1, to_balance: 2,
                                   house_id: rebel.id })
      end.to have_enqueued_job(Ravens::DispatchMessage::ServiceJob).on_queue("ravens")
    end

    it "contributes nothing for a loyal house" do
      expect do
        Servus::Events::Bus.emit(:gold_transferred_event,
                                 { transferred: 10, from_balance: 1, to_balance: 2,
                                   house_id: house.id })
      end.not_to have_enqueued_job(Ravens::DispatchMessage::ServiceJob)
    end
  end

  describe "invocation identity" do
    # An Invocation's key is derived from the service and its params only —
    # scheduling options are deliberately excluded. Two reactions calling the
    # same service with the same arguments are duplicates however they are
    # scheduled, and the Bus keeps the first.
    it "ignores scheduling options when comparing" do
      a = Servus::Events::Invocation.new(
        service: Ravens::DispatchMessage::Service, params: { house_id: 1, message: "x" }, options: {}
      )
      b = Servus::Events::Invocation.new(
        service: Ravens::DispatchMessage::Service, params: { house_id: 1, message: "x" },
        options: { queue: :other, wait: 1.hour }
      )

      expect(a.key).to eq(b.key)
    end

    it "distinguishes different params" do
      a = Servus::Events::Invocation.new(
        service: Ravens::DispatchMessage::Service, params: { house_id: 1, message: "x" }, options: {}
      )
      b = Servus::Events::Invocation.new(
        service: Ravens::DispatchMessage::Service, params: { house_id: 2, message: "x" }, options: {}
      )

      expect(a.key).not_to eq(b.key)
    end
  end

  describe "Bus.subscribe_all" do
    # Every emission is instrumented through ActiveSupport::Notifications, so a
    # subscriber sees the name, payload, and timing of everything on the bus.
    # This is the hook for metrics or an audit log.
    it "observes every event that crosses the bus" do
      seen = []
      subscription = Servus::Events::Bus.subscribe_all { |name, payload, **| seen << [name, payload] }

      RavenRequestedEvent.emit(house_id: house.id, message: "Observed")

      ActiveSupport::Notifications.unsubscribe(subscription)

      expect(seen.map(&:first)).to include(:raven_requested_event)
      expect(seen.last.last[:message]).to eq("Observed")
    end
  end
end
