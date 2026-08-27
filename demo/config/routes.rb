# =============================================================================
# Routes
# =============================================================================
#
# Two endpoints, both thin. Everything they do is delegated to a service via
# `run_service`, which is the point — the controller is a transport layer, not
# a place where behaviour lives.
Rails.application.routes.draw do
  # Servus's run_service in its default form: renders the framework's standard
  # error envelope on failure.
  post "treasury/transfers", to: "treasury/transfers#create"

  # The same helper in a controller that overrides render_service_error, to
  # show the envelope is yours to shape.
  get "citadel/records/:house_id", to: "citadel/records#show"

  get "up" => "rails/health#show", as: :rails_health_check
end
