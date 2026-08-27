# frozen_string_literal: true

module Citadel
  module ConsultRecords
    # =========================================================================
    # Citadel::ConsultRecords::Service — the edges
    # =========================================================================
    #
    # Features exercised:
    #   - A service with NO result schema (require_service_result_schema is off)
    #   - Deeply nested result data, read back through DataObject
    #   - Returning a failure with structured data
    #   - Servus::Support::Errors — several classes, each with its own status
    #
    # -------------------------------------------------------------------------
    # Why no result schema
    # -------------------------------------------------------------------------
    #
    # Every other service in this app declares one. This one deliberately does
    # not, to show what that costs and what it buys.
    #
    # It buys freedom to return an open-ended shape — a records dump whose keys
    # depend on what was found. It costs the guarantee: nothing validates this
    # result, so a change here that breaks a caller is found by that caller,
    # not here.
    #
    # With `config.require_service_result_schema = true` this service would
    # raise SchemaRequiredError on every successful call. That is the stricter
    # posture, and most apps should take it; this one stays lenient so the
    # difference is visible.
    class Service < ApplicationService
      schema arguments: {
        type: "object",
        required: %w[house_id],
        properties: {
          house_id: Servus::Schema.ref("core", "$defs", "record_id"),
          depth: {
            "type" => "string",
            "enum" => %w[shallow full],
            "example" => "full"
          }
        }
      }

      def initialize(house_id:, depth: "shallow")
        @house_id = house_id
        @depth = depth
      end

      def call
        house = House.find(@house_id)

        return sealed_failure if house.vault&.sealed?

        # Nested structure on purpose. On the other side this reads as
        # `result.data.house.vault.gold_dragons` — DataObject re-wraps nested
        # hashes lazily as they are read, so arbitrarily deep access works
        # without the service doing anything special.
        #
        # Arrays of hashes are wrapped element-wise, so
        # `result.data.house.ravens.first.message` works too.
        success(
          house: {
            id: house.id,
            name: house.name,
            standing: house.standing,
            vault: house.vault && {
              id: house.vault.id,
              gold_dragons: house.vault.gold_dragons,
              sealed: house.vault.sealed
            },
            ravens: house.ravens.map { |r| { id: r.id, message: r.message } }
          },
          consulted_at: Time.current.iso8601,
          depth: @depth
        )
      end

      private

      # A failure carrying structured data. The data is validated against the
      # failure schema inherited from ApplicationService — which requires
      # `reason`, so omitting it would raise a ValidationError rather than
      # returning a malformed failure.
      #
      # The error type determines the HTTP status the controller renders:
      # ConflictError is 409, which is the honest answer for "the thing exists
      # but is in a state that forbids this".
      def sealed_failure
        failure(
          "The vault is sealed; records cannot be consulted",
          data: { reason: "vault_sealed", detail: "Unseal the vault first" },
          type: Servus::Support::Errors::ConflictError
        )
      end
    end
  end
end
