# frozen_string_literal: true

# =============================================================================
# ApplicationService — the abstract base every service inherits
# =============================================================================
#
# Features exercised:
#   - Schema inheritance from an abstract base
#   - rescue_from with a `use:` class
#   - rescue_from with a block
#
# ---------------------------------------------------------------------------
# Why have a base class at all?
# ---------------------------------------------------------------------------
#
# Servus is explicit that services are *composed*, not subclassed — one
# concrete service should never inherit another. An abstract base is the
# exception, and a common one: it carries cross-cutting configuration that
# every service in the app shares.
#
# Two things live here.
#
# 1. A shared `failure` schema. Servus schemas are inherited, so declaring one
#    here means every service returns failure data in the same shape without
#    restating it. A subclass may still override it.
#
# 2. `rescue_from` mappings. Infrastructure exceptions — a record that is not
#    there, a network timeout — are not business outcomes, but they should not
#    escape as raw exceptions either. Mapping them once here converts them into
#    ordinary failure Responses that the controller renders like any other.
class ApplicationService < Servus::Base
  # Inherited by every service. A failure carries a machine-readable reason and
  # a human sentence; anything more specific is added by the subclass.
  schema failure: {
    type: "object",
    required: %w[reason],
    properties: {
      reason: {
        type: "string",
        description: "A machine-readable failure reason",
        example: "insufficient_gold"
      },
      detail: {
        type: "string",
        description: "A human-readable explanation",
        example: "Vault holds 100 dragons, needs 500"
      }
    }
  }

  # ---------------------------------------------------------------------------
  # rescue_from, form one: map an exception class to a Servus error
  # ---------------------------------------------------------------------------
  #
  # Without this, an ActiveRecord::RecordNotFound raised anywhere inside `call`
  # would propagate out of the service and 500 the request. With it, the
  # service returns a failure Response whose error is a NotFoundError — which
  # carries :not_found, so the controller renders a 404.
  #
  # Note this is exception -> Response translation, not exception swallowing:
  # the caller still learns it failed and why.
  rescue_from ActiveRecord::RecordNotFound,
              use: Servus::Support::Errors::NotFoundError

  # ---------------------------------------------------------------------------
  # rescue_from, form two: a block, when the mapping needs to think
  # ---------------------------------------------------------------------------
  #
  # The block runs in a restricted context exposing only `success` and
  # `failure` — it cannot reach the service instance, which keeps it a pure
  # translation step rather than a second place business logic can hide.
  #
  # Here it attaches structured failure data matching the schema above, which a
  # bare `use:` mapping could not do.
  rescue_from ActiveRecord::RecordInvalid do |exception|
    failure("Record was invalid: #{exception.message}",
            type: Servus::Support::Errors::UnprocessableEntityError)
  end
end
