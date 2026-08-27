# frozen_string_literal: true

# =============================================================================
# GoldTransferredEvent — the flagship event
# =============================================================================
#
# Features exercised:
#   - schema payload: with $ref into shared fragments
#   - Multiple `enqueue` declarations on one event
#   - Scheduling options: queue:, wait:, priority:
#   - Conditional reaction via if:
#   - A mapper block, and the no-block pass-through form
#
# -----------------------------------------------------------------------------
# The name
# -----------------------------------------------------------------------------
#
# There is no `event_name` here, so Servus infers one from the class name. Note
# what it infers: `GoldTransferredEvent` becomes `:gold_transferred_event` — the
# `Event` suffix is NOT stripped. That is why the emitting service writes
#
#     emits :gold_transferred_event, on: :success
#
# and not `:gold_transferred`. Getting this wrong is quiet: with
# `require_event_payload_schema` off, an emission naming an unregistered event
# does nothing at all. This app turns that flag on, so a mismatch raises.
#
# Inference only happens because the railtie eager-requires every
# `app/events/**/*_event.rb` at boot and calls `ensure_registered!`. A file
# outside that path or without the suffix never registers.
#
# -----------------------------------------------------------------------------
# Why reactions are enqueued, never inline
# -----------------------------------------------------------------------------
#
# Since Servus 1.0 `enqueue` is the only option — there is no synchronous form.
# A reaction that ran inline would put its latency and its failures back into
# the emitting service: a slow ledger write would slow the transfer, and a
# raised exception in an audit log would fail a transfer that already
# succeeded. That coupling is exactly what events exist to remove.
class GoldTransferredEvent < Servus::Event
  # The payload contract. Validated on every emission — and because
  # `config.require_event_payload_schema` is true, an event without one raises
  # rather than passing anything through.
  #
  # The emitting service's success payload defaults to `result.data`, so this
  # schema and the service's `result` schema describe the same hash. They are
  # declared separately on purpose: the event is a published contract that
  # outlives any one producer.
  schema payload: {
    type: "object",
    required: %w[transferred from_balance to_balance],
    properties: {
      transferred: Servus::Schema.ref("core", "$defs", "gold_dragons"),
      from_balance: Servus::Schema.ref("core", "$defs", "gold_dragons"),
      to_balance: Servus::Schema.ref("core", "$defs", "gold_dragons")
    }
  }

  # A reaction with a mapper block. The block turns the event payload into the
  # service's keyword arguments — the service knows nothing about events.
  #
  # `vault_id` is not in the payload, which is deliberate: this event does not
  # publish it, so the reaction cannot have it. Reactions are limited to what
  # the contract promises, which is what keeps the contract meaningful. Here
  # the ledger looks the vault up by balance instead.
  enqueue Ledger::RecordEntry::Service, queue: :ledger do |payload|
    {
      vault: Vault.find_by(gold_dragons: payload[:from_balance]),
      direction: "debit",
      amount: payload[:transferred],
      memo: "Transferred #{payload[:transferred]} dragons"
    }
  end

  # A conditional reaction. When the condition fails nothing is built and
  # nothing is enqueued — the reaction is skipped entirely rather than
  # enqueued-and-discarded.
  #
  # `wait:` and `priority:` are passed through to ActiveJob. Note they are NOT
  # part of an Invocation's identity: two reactions calling the same service
  # with the same params are duplicates regardless of their scheduling, and the
  # Bus keeps only the first.
  enqueue Ravens::DispatchMessage::Service,
          queue: :ravens,
          wait: 1.minute,
          priority: 10,
          if: ->(payload) { payload[:transferred] >= 500 } do |payload|
    {
      house_id: Vault.find_by(gold_dragons: payload[:to_balance])&.house_id || House.first&.id,
      message: "A large transfer of #{payload[:transferred]} dragons has cleared"
    }
  end
end
