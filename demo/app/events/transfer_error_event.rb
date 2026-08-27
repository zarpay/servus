# frozen_string_literal: true

# =============================================================================
# TransferErrorEvent — emitted by error!, before the exception is raised
# =============================================================================
#
# Features exercised:
#   - An event on the :error! trigger
#
# -----------------------------------------------------------------------------
# :error! never coincides with :failure
# -----------------------------------------------------------------------------
#
# `error!` fires its emissions synchronously and then raises. Because the
# exception propagates out of `Servus::Base.call`, the normal after-call path
# that emits `:failure` never runs.
#
# So a service declaring both gets exactly one of them per call: `:failure`
# when it returns a failure Response, `:error!` when it raises. That is worth
# knowing if you are counting events — a spec expecting both from one call will
# wait forever.
class TransferErrorEvent < Servus::Event
  schema payload: {
    type: "object",
    required: %w[reason detail],
    properties: {
      from_vault_id: Servus::Schema.ref("core", "$defs", "record_id"),
      reason: { "type" => "string", "example" => "error" },
      detail: { "type" => "string", "example" => "No raven can reach beyond_the_wall" }
    }
  }
end
