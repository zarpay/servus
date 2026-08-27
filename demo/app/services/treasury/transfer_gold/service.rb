# frozen_string_literal: true

module Treasury
  module TransferGold
    # =========================================================================
    # Treasury::TransferGold::Service — the flagship
    # =========================================================================
    #
    # Features exercised:
    #   - schema arguments: / result: with $ref into shared fragments
    #   - failure schema inherited from ApplicationService
    #   - Built-in guards (state, falsey) and a custom guard
    #   - emits on all three triggers, with block and `with:` payload builders
    #   - Conditional emission via if:
    #   - Multiple events on one trigger
    #   - The async DSL, both keyword and block forms
    #
    # -------------------------------------------------------------------------
    # What a service is for
    # -------------------------------------------------------------------------
    #
    # Everything below the guards is business logic and nothing else. There is
    # no argument checking, no nil handling, no "did they pass an integer" —
    # the arguments schema already rejected anything that would need it, before
    # `call` ran and before this object was even constructed.
    #
    # That is the trade Servus offers: declare the contract once, at the top,
    # and the body gets to assume it.
    #
    # -------------------------------------------------------------------------
    # A note on the schema
    # -------------------------------------------------------------------------
    #
    # Both amounts `$ref` the shared `core` fragment rather than restating
    # `{ type: 'integer', minimum: 0 }`. If the treasury ever moves to a
    # different representation, it changes in config/schemas/westeros.rb and
    # every service that refs it follows.
    #
    # `example:` values on the properties are not decoration — Servus's test
    # helpers read them, so `servus_arguments_example(self)` builds a valid
    # argument hash straight from this declaration. See
    # spec/matchers/servus_matchers_spec.rb.
    class Service < ApplicationService
      schema(
        arguments: {
          type: "object",
          required: %w[from_vault_id to_vault_id gold_dragons],
          properties: {
            from_vault_id: Servus::Schema.ref("core", "$defs", "record_id"),
            to_vault_id: { "$ref" => "#/core/$defs/record_id", "example" => 2 },
            # Sibling keys override the fragment they resolve to: the shared
            # definition allows zero, but a transfer of nothing is meaningless,
            # so this site tightens it to 1 without touching the shared type.
            gold_dragons: {
              "$ref" => "#/core/$defs/gold_dragons",
              "minimum" => 1,
              "description" => "How many dragons to move"
            }
          }
        },
        result: {
          type: "object",
          required: %w[transferred from_balance to_balance],
          properties: {
            transferred: Servus::Schema.ref("core", "$defs", "gold_dragons"),
            from_balance: Servus::Schema.ref("core", "$defs", "gold_dragons"),
            to_balance: Servus::Schema.ref("core", "$defs", "gold_dragons")
          }
        }
      )

      # -----------------------------------------------------------------------
      # Event emission
      # -----------------------------------------------------------------------
      #
      # Three triggers, and more than one event on the success trigger — a
      # trigger holds a list, and each entry gets its own payload.
      #
      # The default success payload is `result.data`, which here happens to
      # match GoldTransferredEvent's schema exactly, so no builder is needed.
      # The other two need shaping, so they use a block and a `with:` method.
      emits :gold_transferred_event, on: :success

      # A second event on the same trigger, with a payload built by a block.
      # The block is instance_exec'd, so it can read ivars as well as `result`.
      emits :vault_audited_event, on: :success do |result|
        { vault_id: from_vault.id, balance: result.data[:from_balance] }
      end

      # Conditional: only fires for transfers the Iron Bank would care about.
      # When the condition fails the event is skipped entirely — no payload is
      # built and nothing reaches the bus.
      emits :large_transfer_event, on: :success,
            if: ->(result) { result.data[:transferred] >= 500 }

      # The failure trigger's default payload is `result.error`, which is a
      # ServiceError object rather than a Hash — so an event with an object
      # payload schema needs a builder. This one names a private method.
      emits :transfer_failed_event, on: :failure, with: :failure_payload

      # Fired by `error!` immediately before it raises. Note this never
      # coincides with :failure — an `error!` exits by exception, so the
      # normal after-call path that emits :failure never runs.
      emits :transfer_error_event, on: :error!, with: :failure_payload

      # -----------------------------------------------------------------------
      # Async configuration
      # -----------------------------------------------------------------------
      #
      # `async` configures the ActiveJob class Servus generates for this
      # service — here, Treasury::TransferGold::ServiceJob. These are
      # class-level defaults; options passed to `.call_async` win per call.
      async queue: :treasury, priority: 5

      # The block form is class_eval'd on the job, so the whole ActiveJob
      # surface is available — retries, discards, callbacks.
      async do
        retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3
        discard_on ActiveJob::DeserializationError
      end

      def initialize(from_vault_id:, to_vault_id:, gold_dragons:)
        @from_vault_id = from_vault_id
        @to_vault_id = to_vault_id
        @gold_dragons = gold_dragons
      end

      def call
        # Guards run first and read like preconditions, because that is what
        # they are. Each halts the service with a structured GuardError if it
        # fails; none of them needs an `if` or a `return`.
        enforce_state!(on: from_vault.house, check: :standing, is: %w[loyal neutral])
        enforce_falsey!(on: from_vault, check: :sealed)
        enforce_sufficient_gold!(vault: from_vault, amount: @gold_dragons)

        # Business logic only, from here down.
        ActiveRecord::Base.transaction do
          from_vault.withdraw!(@gold_dragons)
          to_vault.deposit!(@gold_dragons)
        end

        success(
          transferred: @gold_dragons,
          from_balance: from_vault.gold_dragons,
          to_balance: to_vault.gold_dragons
        )
      end

      private

      # Raises ActiveRecord::RecordNotFound for a bad id, which
      # ApplicationService's rescue_from turns into a NotFoundError failure
      # rather than letting it escape as an exception.
      def from_vault
        @from_vault ||= Vault.find(@from_vault_id)
      end

      def to_vault
        @to_vault ||= Vault.find(@to_vault_id)
      end

      # Shared by the :failure and :error! emissions. Both triggers hand a
      # Response whose `data` is nil and whose `error` carries the detail, so
      # the payload has to be built from the error rather than the data.
      def failure_payload(result)
        {
          from_vault_id: @from_vault_id,
          reason: result.error.respond_to?(:code) ? result.error.code : "error",
          detail: result.error.message
        }
      end
    end
  end
end
