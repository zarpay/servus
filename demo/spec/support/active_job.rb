# frozen_string_literal: true

# =============================================================================
# ActiveJob adapter selection
# =============================================================================
#
# Since Servus 1.0, event invocation ALWAYS enqueues — there is no inline
# option. That makes the adapter choice a per-spec decision:
#
#   default (`:test`)   jobs are recorded, not run. Use when the assertion is
#                       "this was enqueued, on this queue, with these args".
#                       `have_enqueued_job` reads this.
#
#   `:inline_jobs` tag  jobs run immediately on enqueue. Use when the assertion
#                       is about the *effect* — a LedgerEntry row exists, a
#                       Raven was dispatched. Without this, a spec asserting a
#                       side effect of an event reaction would always fail.
#
# The gem's own suite uses the same tag, for the same reason.
#
# ---------------------------------------------------------------------------
# When :inline is NOT enough
# ---------------------------------------------------------------------------
#
# The inline adapter runs a job the moment it is enqueued, which means it
# cannot schedule one for the future. A reaction declared with `wait:` — as
# GoldTransferredEvent's raven is — raises under it:
#
#   NotImplementedError: Use a queueing backend to enqueue jobs in the future
#
# So a spec that needs delayed reactions to actually run has to stay on the
# :test adapter and wrap the action in `perform_enqueued_jobs`, which executes
# scheduled jobs immediately regardless of their delay. See
# spec/integration/treasury_transfer_spec.rb.
RSpec.configure do |config|
  config.before do |example|
    ActiveJob::Base.queue_adapter = example.metadata[:inline_jobs] ? :inline : :test
  end
end
