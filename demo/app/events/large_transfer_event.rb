# frozen_string_literal: true

# =============================================================================
# LargeTransferEvent — the Iron Bank is watching
# =============================================================================
#
# Features exercised:
#   - A reaction with NO mapper block (the full payload is passed through)
#
# -----------------------------------------------------------------------------
# The pass-through form
# -----------------------------------------------------------------------------
#
# `enqueue Service` without a block passes the entire event payload as the
# service's keyword arguments. It is the right form only when the payload
# already matches the service's signature exactly — which is a real coupling,
# and the reason a mapper block is usually better.
#
# Here the payload is shaped to match, so it reads cleanly. Change either side
# and it breaks loudly at the argument schema rather than silently.
class LargeTransferEvent < Servus::Event
  schema payload: {
    type: "object",
    required: %w[house_id message],
    properties: {
      house_id: Servus::Schema.ref("core", "$defs", "record_id"),
      message: { "type" => "string", "example" => "A large transfer has cleared" },
      destination: { "type" => "string", "example" => "iron_bank" }
    }
  }

  # No block: the payload IS the arguments.
  enqueue Ravens::DispatchMessage::Service, queue: :ravens
end
