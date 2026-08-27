# frozen_string_literal: true

module Citadel
  # ===========================================================================
  # Citadel::RecordsController — overriding the error renderer
  # ===========================================================================
  #
  # Features exercised:
  #   - Overriding render_service_error to change the error envelope
  #
  # ---------------------------------------------------------------------------
  # Why override it
  # ---------------------------------------------------------------------------
  #
  # Servus's default renders `{ error: { code:, message: } }` with the error's
  # HTTP status. That is a reasonable default and wrong for plenty of APIs —
  # JSON:API wants `errors: [...]`, some houses want a request id, some want a
  # different key entirely.
  #
  # `render_service_error` is an ordinary method, so overriding it in a
  # controller (or in ApplicationController, for the whole app) changes the
  # envelope everywhere `run_service` is used, without touching a single
  # service. The services still decide *what* failed and with what status; the
  # controller decides how that looks on the wire.
  class RecordsController < ActionController::API
    # GET /citadel/records/:house_id
    def show
      run_service(Citadel::ConsultRecords::Service,
                  { house_id: params[:house_id].to_i, depth: params[:depth] || "shallow" })

      return if performed?

      render json: { records: @result.data.as_json }, status: :ok
    end

    private

    # The override. Note it still reads `http_status` and `api_error` off the
    # error — the shape of the envelope changes, not where the facts come from.
    def render_service_error(error)
      render json: {
        errors: [
          {
            code: error.api_error[:code],
            detail: error.api_error[:message],
            status: Rack::Utils.status_code(error.http_status).to_s
          }
        ]
      }, status: error.http_status
    end
  end
end
