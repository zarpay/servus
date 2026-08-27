# frozen_string_literal: true

# =============================================================================
# RavenRosterRouter — routing as an extension point
# =============================================================================
#
# Features exercised:
#   - Subclassing Servus::Events::Router
#   - Building Servus::Events::Invocation objects by hand
#   - Registering a custom router in Servus.config.routers
#   - Invocation identity / deduplication by service + params
#
# ---------------------------------------------------------------------------
# Why a router at all?
# ---------------------------------------------------------------------------
#
# An Event class answers "what should happen when :gold_transferred_event
# fires?" with a static list of `enqueue` declarations written in Ruby. That is
# the right answer most of the time, and `ClassRouter` is what reads it.
#
# A router is the answer when the reaction list is *data* rather than code —
# subscriptions in a database, a per-tenant config, a feature flag. The Bus
# asks every configured router in order, collects what they return, and
# deduplicates.
#
# This one is deliberately trivial so the mechanism stays visible: any house
# whose standing is "rebellious" gets a raven sent to the capital whenever gold
# moves, and that rule lives here rather than on the Event class because it is
# about *who is watching*, not about what the event means.
#
# ---------------------------------------------------------------------------
# Deduplication
# ---------------------------------------------------------------------------
#
# `Invocation#key` is derived from the service class and params only — options
# such as `queue:` are deliberately excluded. So if this router and an Event
# class both ask for the same service with the same params, the Bus runs it
# once and the first router in `config.routers` wins.
#
# spec/events/raven_roster_router_spec.rb asserts exactly that.
class RavenRosterRouter < Servus::Events::Router
  # @param event_name [Symbol] the emitted event name
  # @param payload [Hash] the event payload
  # @return [Array<Servus::Events::Invocation>]
  def resolve(event_name, payload)
    return [] unless event_name == :gold_transferred_event

    house = House.find_by(id: payload[:house_id])
    return [] unless house&.standing == "rebellious"

    [
      Servus::Events::Invocation.new(
        service: Ravens::DispatchMessage::Service,
        params: {
          house_id: house.id,
          message: "House #{house.name} moved #{payload[:transferred]} dragons"
        },
        # Scheduling options are passed straight through to `call_async`.
        # They are NOT part of the dedup key.
        options: { queue: :ravens }
      )
    ]
  end
end
