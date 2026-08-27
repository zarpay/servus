# frozen_string_literal: true

require "rails_helper"

# =============================================================================
# Servus.config — every option
# =============================================================================
#
# Features exercised:
#   - Every option on Servus::Config, and what this app sets it to
#
# This file is the executable counterpart to config/initializers/servus.rb:
# that file explains each setting, this one proves it took effect.
RSpec.describe Servus.config do
  describe "directory settings" do
    # events_dir and guards_dir are eager-required by the railtie on every boot
    # and reload — an Event or Guard outside them never registers.
    it "points the railtie at where events and guards live" do
      expect(described_class.events_dir).to eq("app/events")
      expect(described_class.guards_dir).to eq("app/guards")
    end

    # services_dir and tests_dir are only read by the generators. Services are
    # autoloaded by Rails like any other class.
    it "points the generators at where services and specs go" do
      expect(described_class.services_dir).to eq("app/services")
      expect(described_class.tests_dir).to eq("spec")
    end

    # Proof the eager-require worked: these classes are registered without any
    # spec having referenced them.
    it "registered every Event class at boot" do
      expect(Servus::Events::Bus.event_for(:gold_transferred_event)).to eq(GoldTransferredEvent)
      expect(Servus::Events::Bus.event_for(:raven_requested_event)).to eq(RavenRequestedEvent)
    end

    it "defined every guard's methods at boot" do
      expect(Servus::Base.instance_methods).to include(:enforce_sufficient_gold!)
      expect(Servus::Base.instance_methods).to include(:enforce_loyal_house!)
    end
  end

  describe "schema enforcement" do
    it "requires an arguments schema on every service" do
      expect(described_class.require_service_arguments_schema).to be(true)
    end

    # Deliberately off, so the harness can also show a service without one.
    # See Citadel::ConsultRecords::Service.
    it "does not require a result schema" do
      expect(described_class.require_service_result_schema).to be(false)
    end

    it "requires a payload schema on every event" do
      expect(described_class.require_event_payload_schema).to be(true)
    end

    # What the arguments flag actually buys: a service without one fails at the
    # call rather than silently validating nothing.
    it "raises for a service with no arguments schema" do
      naked = stub_const("NakedService", Class.new(Servus::Base) do
        def initialize(**) = nil
        def call = success({})
      end)

      expect { naked.call }
        .to raise_error(Servus::Support::Errors::SchemaRequiredError, /require_service_arguments_schema/)
    end
  end

  describe "lockdown" do
    it "is enabled" do
      expect(described_class.lockdown_enabled).to be(true)
    end

    # The whole point: a caller cannot skip the lifecycle that runs validation,
    # guards, logging, and event emission.
    it "makes .new private on every service" do
      expect { Treasury::TransferGold::Service.new(from_vault_id: 1, to_vault_id: 2, gold_dragons: 3) }
        .to raise_error(NoMethodError)
    end
  end

  describe "routers" do
    # Order matters: the Bus asks each in turn and deduplicates, first wins.
    it "runs the class router before the custom one" do
      expect(described_class.routers.map(&:class))
        .to eq([Servus::Events::ClassRouter, RavenRosterRouter])
    end
  end

  describe "log filtering" do
    # Reuses Rails' own request-log filter list rather than maintaining a
    # second one. Note this covers service ARGUMENTS only — event payloads are
    # not filtered.
    #
    # Asserting on the CONTENT rather than on equality with
    # `Rails.application.config.filter_parameters` is deliberate: Rails
    # precompiles that array into a single regexp at some point after
    # initializers run, so the value Servus captured at boot and the value
    # Rails holds later are equivalent but not `==`.
    it "captured the Rails filter list at boot" do
      expect(described_class.log_filter_parameters).to include(:passw, :token, :secret)
    end

    it "builds a parameter filter that masks matching keys" do
      expect(described_class.parameter_filter.filter({ passw: "hunter2" }))
        .to eq({ passw: "[FILTERED]" })
    end
  end

  describe "include_default_guards" do
    # True, which is why PresenceGuard and friends exist. Worth knowing this is
    # read at REQUIRE time inside the gem, not when assigned — so setting it in
    # an initializer would have no effect, because `require "servus"` has
    # already happened by then.
    it "is on, so the built-in guards are available" do
      expect(described_class.include_default_guards).to be(true)
      expect(Servus::Base.instance_methods).to include(:enforce_presence!)
    end
  end
end
