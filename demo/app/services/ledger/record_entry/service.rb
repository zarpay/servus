# frozen_string_literal: true

module Ledger
  module RecordEntry
    # =========================================================================
    # Ledger::RecordEntry::Service — lazy resolvers and nested result data
    # =========================================================================
    #
    # Features exercised:
    #   - The `lazily` DSL: by :id, by another column, and with an Array
    #   - Nested result data and DataObject method access
    #   - A failure carrying structured `data:` validated by the failure schema
    #
    # -------------------------------------------------------------------------
    # What `lazily` is for
    # -------------------------------------------------------------------------
    #
    # A service that takes a `vault_id` has to turn it into a Vault. Written by
    # hand that is a memoized private method per argument — the same six lines
    # repeated for every record the service touches.
    #
    # `lazily` declares it instead:
    #
    #     lazily :vault, finds: Vault
    #
    # and `vault` resolves on first read, memoized thereafter. It accepts
    # either an id or an already-loaded Vault, so a caller that already has the
    # record does not pay for a second query. Resolution happens inside `call`,
    # after argument validation — so the schema sees the raw id.
    #
    # A missing record raises ActiveRecord::RecordNotFound, which
    # ApplicationService's `rescue_from` converts into a NotFoundError failure.
    class Service < ApplicationService
      schema(
        arguments: {
          type: "object",
          required: %w[vault direction amount],
          properties: {
            # Deliberately loose: `lazily` accepts either an id or a record, so
            # the schema cannot demand an integer. This is a real tension worth
            # seeing — a tighter schema here would reject the record form.
            vault: { "description" => "A Vault or its id" },
            direction: { "type" => "string", "enum" => %w[debit credit], "example" => "debit" },
            amount: Servus::Schema.ref("core", "$defs", "gold_dragons"),
            memo: { "type" => "string", "example" => "Transfer to House Tully" }
          }
        },
        result: {
          type: "object",
          required: %w[entry vault],
          properties: {
            # Nested objects in the result are worth demonstrating because of
            # how they read on the other side: `result.data.entry.id` works,
            # because DataObject re-wraps nested hashes as it goes.
            entry: {
              "type" => "object",
              "properties" => {
                "id" => Servus::Schema.ref("core", "$defs", "record_id"),
                "direction" => { "type" => "string", "example" => "debit" },
                "amount" => Servus::Schema.ref("core", "$defs", "gold_dragons")
              }
            },
            vault: { "$ref" => "#/houses/$defs/summary" }
          }
        }
      )

      # Resolved from an id, or passed through untouched if already a Vault.
      lazily :vault, finds: Vault

      def initialize(vault:, direction:, amount:, memo: nil)
        @vault = vault
        @direction = direction
        @amount = amount
        @memo = memo
      end

      def call
        # `vault` here is the resolver, not the raw argument. First read runs
        # the query; later reads are memoized.
        entry = LedgerEntry.create!(
          vault: vault,
          direction: @direction,
          amount: @amount,
          memo: @memo
        )

        success(
          entry: { id: entry.id, direction: entry.direction, amount: entry.amount },
          vault: { id: vault.id, name: vault.house.name, standing: vault.house.standing }
        )
      rescue ActiveRecord::RecordInvalid => e
        # Caught here rather than by ApplicationService's rescue_from so the
        # failure can carry structured data. That data is validated against the
        # inherited failure schema — pass a shape it does not allow and the
        # service raises a ValidationError rather than returning a bad failure.
        failure("Could not record the entry",
                data: { reason: "invalid_entry", detail: e.record.errors.full_messages.to_sentence })
      end
    end
  end
end
