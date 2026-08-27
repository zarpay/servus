# frozen_string_literal: true

require "rails_helper"

# =============================================================================
# Built-in guards
# =============================================================================
#
# Features exercised:
#   - PresenceGuard  enforce_presence! / check_presence?
#   - TruthyGuard    enforce_truthy!   / check_truthy?
#   - FalseyGuard    enforce_falsey!   / check_falsey?
#   - StateGuard     enforce_state!    / check_state?
#
# These four ship with the gem and are loaded whenever
# `config.include_default_guards` is true, which is the default.
#
# Note the config is read at *require* time inside the gem, not when you assign
# it — so switching it off has to happen before `require "servus"`, which an
# initializer is too late for. See config/initializers/servus.rb.
#
# Every guard failure produces the same shape: a failure Response whose error
# is a GuardError carrying a `code` and an `http_status`. Only the code differs.
RSpec.describe "built-in guards" do
  # One fixture service per guard, each doing nothing but running it.
  def service_running(&body)
    stub_const("BuiltinGuardSpec::Subject", Class.new(Servus::Base) do
      schema arguments: { type: "object" }

      define_method(:initialize) { |**args| @args = args }
      define_method(:call) do
        instance_exec(@args, &body)
        success(passed: true)
      end
    end)
  end

  describe "PresenceGuard" do
    # Takes arbitrary keyword arguments and requires every value to be present.
    # "Present" means not nil, and not empty for anything responding to #empty?.
    subject(:service) { service_running { |args| enforce_presence!(**args) } }

    it "passes when every value is present" do
      expect(service.call(name: "Stark", sigil: "direwolf")).to be_service_success
    end

    it "fails on nil" do
      expect(service.call(name: nil)).to be_guard_failure("must_be_present")
    end

    it "fails on an empty string, not just nil" do
      expect(service.call(name: "")).to be_guard_failure("must_be_present")
    end

    it "fails on an empty collection" do
      expect(service.call(banners: [])).to be_guard_failure("must_be_present")
    end

    # Worth knowing: a GuardError's http_status is whatever the guard declared,
    # and the built-ins declare the integer 422. That differs from a plain
    # ServiceError, whose #http_status is a Rack symbol like
    # :unprocessable_entity. Both render correctly — Rails accepts either — but
    # a spec asserting on the value has to know which it is looking at.
    it "reports the integer status the guard declared" do
      expect(service.call(name: nil).error.http_status).to eq(422)
    end
  end

  describe "TruthyGuard" do
    # Reads attributes off an object and requires all of them to be truthy.
    subject(:service) { service_running { |args| enforce_truthy!(**args) } }

    let(:attainted) { create(:house, :attainted) }
    let(:loyal) { create(:house) }

    it "passes when the attribute is truthy" do
      expect(service.call(on: attainted, check: :attainted)).to be_service_success
    end

    it "fails when it is not" do
      expect(service.call(on: loyal, check: :attainted)).to be_guard_failure("must_be_truthy")
    end

    it "accepts an array of attributes and requires all of them" do
      expect(service.call(on: attainted, check: %i[attainted name])).to be_service_success
    end
  end

  describe "FalseyGuard" do
    # The mirror image — every named attribute must be falsey.
    subject(:service) { service_running { |args| enforce_falsey!(**args) } }

    it "passes for an unsealed vault" do
      expect(service.call(on: create(:vault), check: :sealed)).to be_service_success
    end

    it "fails for a sealed one" do
      expect(service.call(on: create(:vault, :sealed), check: :sealed))
        .to be_guard_failure("must_be_falsey")
    end
  end

  describe "StateGuard" do
    # Checks one attribute against an allowed value or set of values. This is
    # the guard to reach for when an attribute has more than two states —
    # Truthy/Falsey cannot express "loyal or neutral, but not rebellious".
    subject(:service) { service_running { |args| enforce_state!(**args) } }

    it "passes when the state matches a single expected value" do
      expect(service.call(on: create(:house), check: :standing, is: "loyal"))
        .to be_service_success
    end

    it "passes when the state is one of several allowed values" do
      house = create(:house, standing: "neutral")

      expect(service.call(on: house, check: :standing, is: %w[loyal neutral]))
        .to be_service_success
    end

    it "fails when the state is outside the allowed set" do
      house = create(:house, :rebellious)

      expect(service.call(on: house, check: :standing, is: %w[loyal neutral]))
        .to be_guard_failure("invalid_state")
    end
  end

  # Every built-in exposes a predicate twin that answers the same question
  # without halting the service.
  describe "the predicate twins" do
    subject(:service) do
      service_running do |args|
        raise "guard disagreed" unless check_presence?(**args)
      end
    end

    it "returns true rather than halting when the check passes" do
      expect(service.call(name: "Stark")).to be_service_success
    end

    it "returns false rather than halting when it does not" do
      expect { service.call(name: nil) }.to raise_error("guard disagreed")
    end
  end
end
