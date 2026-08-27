# frozen_string_literal: true

require "rails_helper"

# =============================================================================
# GET /citadel/records/:house_id — a custom error envelope
# =============================================================================
#
# Features exercised:
#   - Overriding render_service_error
#   - A failure carrying structured data and a non-default error class
#
# -----------------------------------------------------------------------------
# The point of this file
# -----------------------------------------------------------------------------
#
# The transfers controller uses Servus's default envelope,
# `{ error: { code:, message: } }`. This one overrides it to a JSON:API-shaped
# `{ errors: [{ code:, detail:, status: }] }`.
#
# Not one service changed. `render_service_error` is an ordinary method, so the
# wire format is a controller concern and the services keep deciding only what
# failed and with which status.
RSpec.describe "GET /citadel/records/:house_id" do
  let(:house) { create(:house) }

  describe "a successful consultation" do
    let!(:vault) { create(:vault, house: house, gold_dragons: 500) }

    before { get "/citadel/records/#{house.id}" }

    it "responds 200" do
      expect(response).to have_http_status(:ok)
    end

    # This service declares no result schema, so its shape is not validated.
    # The nesting still survives serialization intact.
    it "returns nested records" do
      records = response.parsed_body["records"]

      expect(records.dig("house", "name")).to eq(house.name)
      expect(records.dig("house", "vault", "gold_dragons")).to eq(500)
    end
  end

  describe "a sealed vault" do
    # The service returns a ConflictError failure with structured data.
    # ConflictError's http_status is :conflict, so the response is 409 — a
    # status no other path in this app produces, and one the controller never
    # names.
    let!(:vault) { create(:vault, house: house, sealed: true) }

    before { get "/citadel/records/#{house.id}" }

    it "responds 409" do
      expect(response).to have_http_status(:conflict)
    end

    # The custom envelope: `errors` as an array, `detail` rather than
    # `message`, and a stringified numeric status.
    it "renders the overridden envelope rather than the default" do
      body = response.parsed_body

      expect(body).to have_key("errors")
      expect(body).not_to have_key("error")

      error = body["errors"].first
      expect(error["code"]).to eq(:conflict.to_s)
      expect(error["detail"]).to eq("The vault is sealed; records cannot be consulted")
      expect(error["status"]).to eq("409")
    end
  end

  describe "a house that is not there" do
    before { get "/citadel/records/999999" }

    # Same override, a different error class — 404 rather than 409, and the
    # controller still contains no branching.
    it "responds 404 in the same envelope" do
      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body["errors"].first["status"]).to eq("404")
    end
  end
end
