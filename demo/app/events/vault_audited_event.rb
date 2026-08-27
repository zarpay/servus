# frozen_string_literal: true

# =============================================================================
# VaultAuditedEvent — a schema-only contract
# =============================================================================
#
# Features exercised:
#   - An Event class with a payload schema and NO reactions
#   - An explicit `event_name` rather than an inferred one
#
# -----------------------------------------------------------------------------
# An event with nothing listening is still worth declaring
# -----------------------------------------------------------------------------
#
# This event enqueues nothing. That is not an oversight.
#
# Declaring it does two useful things even with no subscribers. It validates
# the payload on every emission, so a producer that drifts from the contract is
# caught immediately rather than when someone finally subscribes. And it
# documents that the event exists — a future reaction has something to read.
#
# Emitting an unregistered event name, by contrast, is silently ignored unless
# `require_event_payload_schema` is on. This app turns it on precisely so that
# never happens.
#
# -----------------------------------------------------------------------------
# Explicit naming
# -----------------------------------------------------------------------------
#
# Unlike GoldTransferredEvent, this one names itself explicitly. The value
# happens to match what inference would produce, which makes it a good place to
# note that being explicit is never wrong — and is necessary whenever the
# desired name and the class name diverge.
class VaultAuditedEvent < Servus::Event
  event_name :vault_audited_event

  schema payload: {
    type: "object",
    required: %w[vault_id balance],
    properties: {
      vault_id: Servus::Schema.ref("core", "$defs", "record_id"),
      balance: Servus::Schema.ref("core", "$defs", "gold_dragons")
    }
  }
end
