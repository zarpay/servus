# frozen_string_literal: true

require "rails_helper"

# =============================================================================
# End-to-end: a gold transfer, from HTTP request to background reaction
# =============================================================================
#
# Every other spec in this suite tests one feature in isolation. This one
# follows a single transfer all the way through, because the argument for
# Servus is not any individual feature — it is what the pieces do together.
#
# The path:
#
#   1. A request arrives at a controller that contains no business logic.
#   2. `run_service` calls the service, which validates its arguments against
#      a schema built from shared fragments.
#   3. Three guards check preconditions and would halt with structured errors.
#   4. The body runs — business logic only, no defensive checks.
#   5. The result is validated against the result schema.
#   6. Events are emitted: one unconditionally, one built by a block, one only
#      because this transfer is large enough.
#   7. Reactions are ENQUEUED, never run inline, so the response returns
#      without waiting for a ledger write or a raven.
#   8. The jobs run and their effects land.
#
# Steps 2 through 6 are declared, not written. That is the whole pitch.
# Note the adapter choice. The obvious move is `:inline_jobs`, but one of the
# reactions here is declared with `wait: 1.minute`, and the inline adapter
# cannot schedule a job for the future — it raises NotImplementedError.
#
# So this spec stays on the :test adapter and wraps each action in
# `perform_enqueued_jobs`, which runs scheduled jobs immediately whatever their
# delay. That is the tool for "run the reactions and let me assert the effect"
# whenever any reaction is delayed.
RSpec.describe "a gold transfer, end to end" do
  let!(:stark) { create(:house, name: "Stark", standing: "loyal") }
  let!(:tully) { create(:house, name: "Tully", standing: "loyal") }
  let!(:winterfell) { create(:vault, house: stark, gold_dragons: 5_000) }
  let!(:riverrun) { create(:vault, house: tully, gold_dragons: 0) }

  def post_transfer(amount)
    perform_enqueued_jobs do
      post "/treasury/transfers",
           params: { from_vault_id: winterfell.id, to_vault_id: riverrun.id, gold_dragons: amount },
           as: :json
    end
  end

  # The same request WITHOUT running the reactions, for asserting that the
  # response does not wait on them.
  def post_transfer_without_reactions(amount)
    post "/treasury/transfers",
         params: { from_vault_id: winterfell.id, to_vault_id: riverrun.id, gold_dragons: amount },
         as: :json
  end

  describe "a large transfer" do
    it "responds successfully with the new balances" do
      post_transfer(600)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig("transfer", "from_balance")).to eq(4_400)
      expect(response.parsed_body.dig("transfer", "to_balance")).to eq(600)
    end

    it "moves the gold" do
      post_transfer(600)

      expect(winterfell.reload.gold_dragons).to eq(4_400)
      expect(riverrun.reload.gold_dragons).to eq(600)
    end

    # The transfer service knows nothing about the ledger. The only connection
    # is an event name.
    it "writes a ledger entry it never asked for" do
      expect { post_transfer(600) }.to change(LedgerEntry, :count).by(1)

      entry = LedgerEntry.last
      expect(entry.amount).to eq(600)
      expect(entry.direction).to eq("debit")
    end

    # Two separate reactions send ravens: the conditional one on
    # GoldTransferredEvent, and the one on LargeTransferEvent. Both only fire
    # because the amount cleared the threshold.
    it "sends the ravens that a large transfer warrants" do
      expect { post_transfer(600) }.to change(Raven, :count)

      expect(Raven.pluck(:message).join(" ")).to include("600")
    end
  end

  describe "a small transfer" do
    # Same code path, different outcome — because two of the reactions are
    # conditional and the condition is evaluated per emission.
    it "still records the ledger entry" do
      expect { post_transfer(10) }.to change(LedgerEntry, :count).by(1)
    end

    it "sends no ravens" do
      expect { post_transfer(10) }.not_to change(Raven, :count)
    end
  end

  describe "when a guard refuses" do
    before { stark.update!(standing: "rebellious") }

    it "reports the guard's status and code" do
      post_transfer(600)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_state")
    end

    it "moves no gold" do
      expect { post_transfer(600) }.not_to change { winterfell.reload.gold_dragons }
    end

    # The reactions belong to the success path, so nothing downstream happened
    # either. A failure is contained.
    it "triggers no reactions" do
      expect { post_transfer(600) }.not_to change(LedgerEntry, :count)
      expect { post_transfer(600) }.not_to change(Raven, :count)
    end
  end

  describe "what the caller never has to do" do
    # A summary of the argument, as executable assertions.
    # Note this uses the non-wrapping helper. `perform_enqueued_jobs` comes
    # from ActiveJob's Minitest-based test helper, which re-wraps any exception
    # raised inside it as Minitest::UnexpectedError — so an assertion about the
    # exception CLASS has to run outside it. Argument validation happens long
    # before any job is enqueued, so nothing is lost.
    it "never type-checks its own arguments" do
      expect { post_transfer_without_reactions("six hundred") }
        .to raise_error(Servus::Support::Errors::ValidationError)
    end

    it "never waits for the reactions" do
      # Without perform_enqueued_jobs the reactions stay queued, and the
      # response still returns successfully. That is the whole point of
      # event invocation being asynchronous: the caller does not pay for
      # anything downstream.
      post_transfer_without_reactions(600)

      expect(response).to have_http_status(:created)
      expect(LedgerEntry.count).to eq(0)
      expect(enqueued_jobs.size).to be >= 1
    end
  end
end
