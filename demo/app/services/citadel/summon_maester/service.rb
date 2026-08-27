# frozen_string_literal: true

module Citadel
  module SummonMaester
    # =========================================================================
    # Citadel::SummonMaester::Service — the other shapes of `lazily`
    # =========================================================================
    #
    # Features exercised:
    #   - lazily with `by:` a column other than the primary key
    #   - lazily with an Array argument, resolving to a relation
    #   - `success(nil)` — a service that acts but returns nothing
    #
    # A separate service from Ledger::RecordEntry because `lazily` has three
    # distinct behaviours and cramming them into one service would make none of
    # them legible.
    #
    # -------------------------------------------------------------------------
    # The ivar naming rule
    # -------------------------------------------------------------------------
    #
    # `lazily :house` defines a `house` reader that reads and writes `@house`.
    # So the constructor must assign the *lookup value* to `@house`, not to
    # some other ivar — the resolver replaces it in place on first read.
    #
    # That is easy to get wrong: assigning `@house_name` and declaring
    # `lazily :house` gives you a resolver looking at a nil ivar, which raises
    # NotFoundError with a message about a nil argument. The names must line up.
    class Service < ApplicationService
      schema arguments: {
        type: "object",
        required: %w[house],
        properties: {
          house: {
            "type" => "string",
            "description" => "A house NAME — resolved via find_by!(name:)",
            "example" => "House 1"
          },
          witnesses: {
            "type" => "array",
            "items" => Servus::Schema.ref("core", "$defs", "record_id"),
            "description" => "House ids, resolved as a relation",
            "example" => [1, 2]
          }
        }
      }

      # `by:` resolves through `find_by!` on the named column rather than
      # `find` on the id. Useful when the caller knows a natural key — a
      # webhook, a CLI — rather than a database id.
      lazily :house, finds: House, by: :name

      # An Array argument resolves to `House.where(id: [...])`: a relation, not
      # an Array. That difference matters. It is lazy and chainable, and it
      # does NOT raise for ids that are not there — a missing id is simply
      # absent from the result, which is the opposite of the singular form.
      lazily :witnesses, finds: House

      def initialize(house:, witnesses: [])
        @house = house
        @witnesses = witnesses
      end

      def call
        Raven.create!(
          house: house,
          message: "The maester is summoned to #{house.name} " \
                   "before #{witnesses.count} witness(es)",
          destination: "citadel",
          dispatched_at: Time.current
        )

        # A service that performs an action but has nothing meaningful to
        # return. `success(nil)` is legal and idiomatic: the Response is still
        # a success, `data` is just nil.
        #
        # This is one reason `require_service_result_schema` is left off in
        # this app — with it on, a service returning nil would still need a
        # result schema describing nothing.
        success(nil)
      end
    end
  end
end
