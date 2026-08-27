# frozen_string_literal: true

require "rails_helper"

# =============================================================================
# POST /treasury/transfers — Servus at the HTTP boundary
# =============================================================================
#
# Features exercised:
#   - run_service rendering success and failure
#   - render_service_error's default envelope
#   - Each error class mapping to its own HTTP status, with no controller
#     branching
#
# -----------------------------------------------------------------------------
# What these specs are really asserting
# -----------------------------------------------------------------------------
#
# The controller contains no error handling. Every status below is decided by
# the service layer — a guard's declared http_status, a rescue_from mapping, an
# error class's default — and transported unchanged.
#
# So this file is the proof that the abstraction holds: change what a service
# returns and the HTTP response follows, without touching the controller.
RSpec.describe "POST /treasury/transfers" do
  let(:from_house) { create(:house) }
  let(:from_vault) { create(:vault, house: from_house, gold_dragons: 1_000) }
  let(:to_vault) { create(:vault, gold_dragons: 0) }

  def post_transfer(amount, from: from_vault, to: to_vault)
    post "/treasury/transfers",
         params: { from_vault_id: from.id, to_vault_id: to.id, gold_dragons: amount },
         as: :json
  end

  describe "a successful transfer" do
    before { post_transfer(250) }

    it "responds 201" do
      expect(response).to have_http_status(:created)
    end

    # `run_service` put the Response in @result; the action rendered its data.
    it "returns the service's result data" do
      body = response.parsed_body

      expect(body.dig("transfer", "transferred")).to eq(250)
      expect(body.dig("transfer", "from_balance")).to eq(750)
      expect(body.dig("transfer", "to_balance")).to eq(250)
    end

    it "actually moved the gold" do
      expect(from_vault.reload.gold_dragons).to eq(750)
    end
  end

  describe "a guard failure" do
    # SufficientGoldGuard declares http_status 422 and error_code
    # "insufficient_gold". Both arrive here untouched.
    before { post_transfer(99_999) }

    it "responds with the status the guard declared" do
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "renders the guard's error code and message" do
      body = response.parsed_body

      expect(body.dig("error", "code")).to eq("insufficient_gold")
      expect(body.dig("error", "message")).to eq("Vault holds 1000 dragons, needs 99999")
    end
  end

  describe "a different guard, a different status" do
    # LoyalHouseGuard is not on this path, but StateGuard is — and it declares
    # its own code. Nothing in the controller distinguishes them.
    before do
      from_house.update!(standing: "rebellious")
      post_transfer(10)
    end

    it "renders that guard's code" do
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_state")
    end
  end

  describe "a record that is not there" do
    # ApplicationService's rescue_from turns RecordNotFound into a
    # NotFoundError, whose http_status is :not_found.
    before do
      post "/treasury/transfers",
           params: { from_vault_id: 999_999, to_vault_id: to_vault.id, gold_dragons: 1 },
           as: :json
    end

    it "responds 404 rather than 500" do
      expect(response).to have_http_status(:not_found)
    end

    it "renders the standard error envelope" do
      expect(response.parsed_body["error"]).to include("code", "message")
    end
  end

  describe "arguments that fail the schema" do
    # A ValidationError is a caller bug, not a business outcome — the service
    # raises rather than returning a failure. `run_service` does not rescue it,
    # so it reaches Rails' exception handling.
    #
    # That is deliberate: a malformed request should be caught in development
    # and by the API's own parameter handling, not quietly rendered as though
    # the domain rejected it.
    it "raises rather than rendering a failure" do
      expect { post_transfer(0) }
        .to raise_error(Servus::Support::Errors::ValidationError, /gold_dragons/)
    end
  end
end
