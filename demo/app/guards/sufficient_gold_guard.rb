# frozen_string_literal: true

# =============================================================================
# SufficientGoldGuard — a custom guard, the full DSL
# =============================================================================
#
# Features exercised:
#   - Subclassing Servus::Guard
#   - http_status / error_code / message with a data block
#   - #test, and kwargs reached via method_missing
#   - The generated enforce_sufficient_gold! / check_sufficient_gold? pair
#
# ---------------------------------------------------------------------------
# Why this is a guard and not an `if` in the service
# ---------------------------------------------------------------------------
#
# "Does this vault hold enough gold?" is a precondition, not business logic.
# Written inline it would be three lines of branching that every caller has to
# read past. As a guard it becomes one declarative line in the service:
#
#     enforce_sufficient_gold!(vault: @vault, amount: @gold_dragons)
#
# and — more importantly — the failure it produces is *structured*. A guard
# failure carries an HTTP status and an error code all the way out to the
# controller, which renders them without knowing what a vault is. A bare
# `return failure("not enough gold")` would carry neither.
#
# ---------------------------------------------------------------------------
# Naming
# ---------------------------------------------------------------------------
#
# The method names are derived from the class name: `SufficientGoldGuard` drops
# the `Guard` suffix and underscores to `sufficient_gold`, producing
# `enforce_sufficient_gold!` and `check_sufficient_gold?` on every service.
#
# Registration happens in `Servus::Guard.inherited`, which fires when the file
# loads. Rails only loads it because the railtie eager-requires every
# `*_guard.rb` under `config.guards_dir`. A guard outside that path, or named
# without the `_guard.rb` suffix, silently never defines its methods.
class SufficientGoldGuard < Servus::Guard
  # Rendered by the controller as the response status when this guard fails.
  http_status 422

  # Surfaces to API clients as `error.code`. Stable, machine-readable, and
  # distinct from the human message below.
  error_code "insufficient_gold"

  # The message template uses %<key>s interpolation. The block supplies the
  # data, and is evaluated in the guard instance — so it can read the same
  # kwargs `#test` reads.
  message "Vault holds %<balance>s dragons, needs %<needed>s" do
    { balance: vault.gold_dragons, needed: amount }
  end

  # Return truthy to pass, falsey to fail. `vault` and `amount` are not methods
  # defined anywhere — Servus::Guard's method_missing resolves them from the
  # kwargs passed to enforce_sufficient_gold!.
  #
  # Careful: that method_missing falls through to `super` for falsey values, so
  # a kwarg legitimately passed as `false` or `nil` raises NoMethodError rather
  # than returning nil. Guards should take the things they need, not optional
  # flags.
  def test
    vault.gold_dragons >= amount
  end
end
