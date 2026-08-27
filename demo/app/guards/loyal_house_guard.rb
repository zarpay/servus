# frozen_string_literal: true

# =============================================================================
# LoyalHouseGuard — a guard whose message comes from I18n
# =============================================================================
#
# Features exercised:
#   - message declared as a Symbol rather than a String
#   - Servus::Support::MessageResolver's I18n lookup path
#   - Interpolation data supplied to a translated message
#
# ---------------------------------------------------------------------------
# String vs Symbol messages
# ---------------------------------------------------------------------------
#
# SufficientGoldGuard passes a String template, which is right when the message
# is developer-facing or the app is single-locale.
#
# Passing a Symbol instead sends the message through
# `Servus::Support::MessageResolver`, which looks it up under the `guards.`
# I18n scope — here `guards.disloyal_house` in config/locales/en.yml. Use this
# when the message reaches an end user and the app speaks more than one
# language.
#
# The resolver also accepts a Proc (evaluated in the guard) or a Hash of
# locale => String. If the key is missing it falls back to a humanized version
# of the symbol rather than raising, so a missing translation degrades rather
# than breaking the request.
class LoyalHouseGuard < Servus::Guard
  http_status 403
  error_code "disloyal_house"

  # Resolved via I18n as `guards.disloyal_house`. The data block supplies the
  # interpolation variables the translation expects.
  message :disloyal_house do
    { name: house.name, standing: house.standing }
  end

  def test
    house.standing == "loyal"
  end
end
