# frozen_string_literal: true

module Ravens
  module DispatchMessage
    # =========================================================================
    # Ravens::DispatchMessage::Service — the target of async work
    # =========================================================================
    #
    # Features exercised:
    #   - A service designed to be enqueued rather than called inline
    #   - The generated named job class (Ravens::DispatchMessage::ServiceJob)
    #   - `error!` — halting by exception rather than returning a failure
    #
    # -------------------------------------------------------------------------
    # Why this one is called asynchronously
    # -------------------------------------------------------------------------
    #
    # Dispatching a raven is slow and nobody waiting on a gold transfer needs
    # it to finish first. Since Servus 1.0 every event reaction is enqueued, so
    # this is what an event-driven reaction looks like from the inside: an
    # ordinary service, with no awareness that it was reached from an event.
    #
    # Servus generates `Ravens::DispatchMessage::ServiceJob` for it
    # automatically — a named job per service, so a Sidekiq or GoodJob
    # dashboard shows which service ran rather than one generic wrapper for
    # everything.
    class Service < ApplicationService
      schema arguments: {
        type: "object",
        required: %w[house_id message],
        properties: {
          house_id: Servus::Schema.ref("core", "$defs", "record_id"),
          message: { "type" => "string", "example" => "Winter is coming" },
          destination: { "type" => "string", "example" => "kings_landing" }
        }
      }

      # Ravens are cheap and numerous; give them their own queue so they cannot
      # crowd out treasury work.
      async queue: :ravens

      def initialize(house_id:, message:, destination: "kings_landing")
        @house_id = house_id
        @message = message
        @destination = destination
      end

      def call
        # `error!` halts by raising rather than returning a failure Response.
        #
        # The distinction matters: a failure is an outcome the caller should
        # handle, while `error!` says the situation is not recoverable and
        # should propagate. In a job that means the job fails and ActiveJob's
        # retry policy takes over — which is what you want for a genuinely
        # broken state, and not what you want for "the house was rebellious".
        #
        # Note it also fires any `on: :error!` emissions before raising.
        error!("No raven can reach #{@destination}", type: Servus::Support::Errors::ServiceError) if unreachable?

        raven = Raven.create!(
          house: House.find(@house_id),
          message: @message,
          destination: @destination,
          dispatched_at: Time.current
        )

        success(raven_id: raven.id, dispatched_at: raven.dispatched_at.iso8601)
      end

      private

      def unreachable?
        @destination == "beyond_the_wall"
      end
    end
  end
end
