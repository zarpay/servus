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
RSpec.configure do |config|
  config.before do |example|
    ActiveJob::Base.queue_adapter = example.metadata[:inline_jobs] ? :inline : :test
  end
end
