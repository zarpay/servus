# frozen_string_literal: true

# =============================================================================
# LargeTransferEvent — the Iron Bank is watching
# =============================================================================
#
# Features exercised:
#   - A conditionally-emitted event
#   - A mapper block translating an event payload into service arguments
#
# -----------------------------------------------------------------------------
# The payload describes the EVENT, not the reaction
# -----------------------------------------------------------------------------
#
# This event is emitted with the transfer's result data, so that is what its
# schema describes. It is tempting to shape an event's payload around whatever
# service happens to react to it — and it is a mistake, because the event is a
# published contract that outlives any one subscriber. Add a second reaction
# tomorrow and a payload shaped for the first one will not fit.
#
# The mapper block is where the translation belongs. It turns "what happened"
# into "what this particular service needs", and each reaction gets its own.
#
# See RavenRequestedEvent for the case where a payload genuinely does match a
# service's arguments, and the block can be dropped.
class LargeTransferEvent < Servus::Event
  schema payload: {
    type: "object",
    required: %w[transferred from_balance to_balance],
    properties: {
      transferred: Servus::Schema.ref("core", "$defs", "gold_dragons"),
      from_balance: Servus::Schema.ref("core", "$defs", "gold_dragons"),
      to_balance: Servus::Schema.ref("core", "$defs", "gold_dragons")
    }
  }

  # The block maps the event's vocabulary onto the service's.
  enqueue Ravens::DispatchMessage::Service, queue: :ravens do |payload|
    {
      house_id: House.first&.id,
      message: "The Iron Bank notes a transfer of #{payload[:transferred]} dragons",
      destination: "iron_bank"
    }
  end
end
