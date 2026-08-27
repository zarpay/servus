# frozen_string_literal: true

module Treasury
  # ===========================================================================
  # Treasury::TransfersController — Servus at the HTTP boundary
  # ===========================================================================
  #
  # Features exercised:
  #   - run_service
  #   - render_service_error
  #   - @result, set by run_service for the rest of the action to read
  #
  # ---------------------------------------------------------------------------
  # What run_service does
  # ---------------------------------------------------------------------------
  #
  # `run_service(Klass, params)` calls the service, stores the full Response in
  # `@result`, and — on failure — renders a JSON error using the error's own
  # `http_status` and `api_error`. On success it renders nothing, leaving the
  # action to decide.
  #
  # That is the whole integration. The controller never asks what kind of
  # failure it was: a guard failure renders 422 with its error code, a missing
  # record renders 404, a sealed vault renders 409, and this file contains no
  # branching for any of them. The service layer decided; the controller
  # transports.
  #
  # ---------------------------------------------------------------------------
  # Why ActionController::API
  # ---------------------------------------------------------------------------
  #
  # Servus's helpers are mixed into ActionController::Base AND
  # ActionController::API by the railtie, so either works. This app is an API
  # harness, so API is the honest base class.
  class TransfersController < ActionController::API
    # POST /treasury/transfers
    def create
      run_service(Treasury::TransferGold::Service, transfer_params)

      # `run_service` already rendered if the service failed. `performed?` is
      # how the action knows not to render twice.
      return if performed?

      render json: { transfer: @result.data.as_json }, status: :created
    end

    private

    def transfer_params
      {
        from_vault_id: params[:from_vault_id]&.to_i,
        to_vault_id: params[:to_vault_id]&.to_i,
        gold_dragons: params[:gold_dragons]&.to_i
      }
    end
  end
end
