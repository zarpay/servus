# frozen_string_literal: true

require "rails_helper"

# =============================================================================
# Logging
# =============================================================================
#
# Features exercised:
#   - The call / success / failure / guard-failure log lines
#   - log_filter_parameters masking sensitive arguments
#   - Event emission logging via Bus.enable_logging!
#
# -----------------------------------------------------------------------------
# What Servus logs for free
# -----------------------------------------------------------------------------
#
# Every service call produces a line on the way in and a line on the way out,
# with a duration. Nothing in a service asks for this — it is part of the
# lifecycle that `.call` runs, which is one of the things lockdown exists to
# stop callers from skipping.
RSpec.describe "logging" do
  let(:house) { create(:house) }
  let(:from_vault) { create(:vault, house: house, gold_dragons: 1_000) }
  let(:to_vault) { create(:vault, gold_dragons: 0) }

  # Capture what Servus writes by swapping in a StringIO-backed logger.
  def captured_log
    io = StringIO.new
    original = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = original
  end

  describe "a successful call" do
    subject(:log) do
      captured_log do
        Treasury::TransferGold::Service.call(
          from_vault_id: from_vault.id, to_vault_id: to_vault.id, gold_dragons: 10
        )
      end
    end

    it "logs the call with its arguments" do
      expect(log).to include("Calling Treasury::TransferGold::Service with args:")
      expect(log).to include("gold_dragons: 10")
    end

    it "logs the outcome with a duration" do
      expect(log).to match(/Treasury::TransferGold::Service succeeded in [\d.]+s/)
    end
  end

  describe "a guard failure" do
    subject(:log) do
      captured_log do
        Treasury::TransferGold::Service.call(
          from_vault_id: from_vault.id, to_vault_id: to_vault.id, gold_dragons: 99_999
        )
      end
    end

    # Guard failures get their own line, at warn rather than info, naming the
    # guard's message.
    it "logs the guard's message" do
      expect(log).to include("guard failed: Vault holds 1000 dragons, needs 99999")
    end
  end

  describe "filtered arguments" do
    # config.log_filter_parameters reuses Rails' request-log filter list, so a
    # service argument matching one of those patterns is masked in the log
    # line — the same protection request logging already gives you.
    it "masks a sensitive argument rather than logging it" do
      secretive = stub_const("SecretiveService", Class.new(ApplicationService) do
        schema arguments: { type: "object", required: %w[token], properties: { token: { "type" => "string" } } }

        def initialize(token:) = @token = token
        def call = success(ok: true)
      end)

      log = captured_log { secretive.call(token: "hunter2") }

      expect(log).to include("[FILTERED]")
      expect(log).not_to include("hunter2")
    end

    # Worth knowing: the filter applies to service ARGUMENTS. Event payloads
    # go through a different path and are NOT filtered, so a secret put into a
    # payload will appear in the log.
    it "does not mask event payloads" do
      log = captured_log do
        RavenRequestedEvent.emit(house_id: house.id, message: "a token: hunter2")
      end

      expect(log).to include("hunter2")
    end
  end

  describe "event logging" do
    # Bus.enable_logging! is called by the railtie at boot, so every emission
    # is logged with its name, payload, and how long the dispatch took.
    it "logs each event with its timing" do
      log = captured_log { RavenRequestedEvent.emit(house_id: house.id, message: "Observed") }

      expect(log).to match(/Event :raven_requested_event \([\d.]+ms\)/)
    end
  end
end
