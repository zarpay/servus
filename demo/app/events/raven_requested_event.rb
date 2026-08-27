# frozen_string_literal: true

# =============================================================================
# RavenRequestedEvent — the pass-through reaction, and Event.emit
# =============================================================================
#
# Features exercised:
#   - `enqueue Service` with NO mapper block
#   - An event emitted directly rather than by a service's `emits`
#
# -----------------------------------------------------------------------------
# When the block can be dropped
# -----------------------------------------------------------------------------
#
# `enqueue Service` without a block passes the whole payload as the service's
# keyword arguments. That is only correct when the payload already matches the
# service's signature — which is a real coupling between the two, and usually a
# reason to prefer a mapper block.
#
# Here it is honest: the event means "somebody asked for a raven", and its
# payload is exactly a raven request. There is nothing to translate.
#
# If either side drifts, the failure is loud rather than silent: the service's
# argument schema rejects the payload and raises a ValidationError.
#
# -----------------------------------------------------------------------------
# Emitting without a service
# -----------------------------------------------------------------------------
#
# Most events in this app are emitted by a service's `emits` declaration. This
# one is emitted directly:
#
#     RavenRequestedEvent.emit(house_id: 1, message: "Winter is coming")
#
# which validates the payload and puts it on the bus, exactly as `emits` would.
# Useful from a controller, a rake task, or a console — anywhere that is not a
# service but still has something to announce.
class RavenRequestedEvent < Servus::Event
  schema payload: {
    type: "object",
    required: %w[house_id message],
    properties: {
      house_id: Servus::Schema.ref("core", "$defs", "record_id"),
      message: { "type" => "string", "example" => "Winter is coming" },
      destination: { "type" => "string", "example" => "kings_landing" }
    }
  }

  # No block: the payload IS the arguments.
  enqueue Ravens::DispatchMessage::Service, queue: :ravens
end
