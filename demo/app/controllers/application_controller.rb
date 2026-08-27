# =============================================================================
# ApplicationController
# =============================================================================
#
# Servus's `run_service` and `render_service_error` are mixed into every
# controller automatically by the railtie's `on_load(:action_controller)` hook.
# Nothing needs including here.
#
# This app is an API harness, so the controllers below it inherit from
# ActionController::API rather than this class. See
# app/controllers/treasury/transfers_controller.rb.
class ApplicationController < ActionController::Base
  allow_browser versions: :modern
end
