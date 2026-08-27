# frozen_string_literal: true

# =============================================================================
# TransferFailedEvent and TransferErrorEvent — the unhappy paths
# =============================================================================
#
# Features exercised:
#   - Events for the :failure and :error! emission triggers
#
# -----------------------------------------------------------------------------
# Why failure payloads need a builder
# -----------------------------------------------------------------------------
#
# The default payload for the :success trigger is `result.data` — a Hash, which
# a payload schema can describe directly.
#
# For :failure and :error! the default is `result.error`, which is a
# ServiceError *object*, not a Hash. It will not satisfy a
# `type: 'object', properties: {...}` schema.
#
# So any failure event with a schema needs its producer to build the payload —
# see `failure_payload` in Treasury::TransferGold::Service, which both triggers
# share via `with:`.
class TransferFailedEvent < Servus::Event
  schema payload: {
    type: "object",
    required: %w[reason detail],
    properties: {
      from_vault_id: Servus::Schema.ref("core", "$defs", "record_id"),
      reason: { "type" => "string", "example" => "insufficient_gold" },
      detail: { "type" => "string", "example" => "Vault holds 100 dragons, needs 500" }
    }
  }
end
