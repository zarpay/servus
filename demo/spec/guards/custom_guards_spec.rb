# frozen_string_literal: true

require "rails_helper"

# =============================================================================
# Custom guards
# =============================================================================
#
# Features exercised:
#   - The generated enforce_<name>! / check_<name>? method pair
#   - GuardError carrying error_code and http_status out to the caller
#   - String message templates with a data block
#   - Symbol messages resolved through I18n
#   - Servus::Guard.execute! / .execute? called directly
#
# Guards are tested through a service, because that is where they run: the
# `throw :guard_failure` they raise is caught by `Servus::Base.call`, which
# converts it into a failure Response. Calling a guard outside that catch would
# be testing a mechanism no caller ever sees.
RSpec.describe "custom guards" do
  # A minimal service whose only job is to run one guard. Real services do more,
  # but a focused fixture keeps the assertions about the guard.
  let(:gold_service) do
    stub_const("GuardSpec::MoveGold", Class.new(Servus::Base) do
      schema arguments: { type: "object", required: %w[vault amount] }

      def initialize(vault:, amount:)
        @vault = vault
        @amount = amount
      end

      def call
        enforce_sufficient_gold!(vault: @vault, amount: @amount)
        success(moved: @amount)
      end
    end)
  end

  let(:house_service) do
    stub_const("GuardSpec::ActOnBehalf", Class.new(Servus::Base) do
      schema arguments: { type: "object", required: %w[house] }

      def initialize(house:)
        @house = house
      end

      def call
        enforce_loyal_house!(house: @house)
        success(acted: true)
      end
    end)
  end

  describe "SufficientGoldGuard" do
    let(:vault) { create(:vault, gold_dragons: 100) }

    it "lets the service proceed when the vault holds enough" do
      expect(gold_service.call(vault: vault, amount: 50)).to be_service_success
    end

    it "halts the service when it does not" do
      result = gold_service.call(vault: vault, amount: 500)

      expect(result).to be_guard_failure("insufficient_gold")
    end

    # The whole reason this is a guard: the failure carries a machine-readable
    # code and an HTTP status that the controller renders without knowing
    # anything about vaults.
    it "carries its error code and http status on the error" do
      result = gold_service.call(vault: vault, amount: 500)

      expect(result.error.code).to eq("insufficient_gold")
      expect(result.error.http_status).to eq(422)
    end

    it "interpolates the message template from the data block" do
      result = gold_service.call(vault: vault, amount: 500)

      expect(result.error.message).to eq("Vault holds 100 dragons, needs 500")
    end

    # The predicate twin asks the same question without halting anything.
    it "exposes a non-halting predicate" do
      checker = stub_const("GuardSpec::Checker", Class.new(Servus::Base) do
        schema arguments: { type: "object", required: %w[vault] }

        def initialize(vault:)
          @vault = vault
        end

        def call
          success(enough: check_sufficient_gold?(vault: @vault, amount: 1),
                  plenty: check_sufficient_gold?(vault: @vault, amount: 10_000))
        end
      end)

      result = checker.call(vault: vault)

      expect(result).to be_service_success
      expect(result.data.enough).to be(true)
      expect(result.data.plenty).to be(false)
    end

    # A trap worth knowing about. Servus::Guard#method_missing returns
    # `kwargs[name]` — but only for truthy values; a nil or false falls through
    # to `super` and raises NameError rather than returning nil.
    #
    # In practice this means a guard should take the things it needs, not
    # optional flags. Passing `vault: nil` is a caller bug, and this is how it
    # surfaces.
    it "raises rather than silently passing when a required kwarg is nil" do
      expect { Servus::Guard.execute?(SufficientGoldGuard, vault: nil, amount: 1) }
        .to raise_error(NameError, /vault/)
    end
  end

  describe "LoyalHouseGuard" do
    it "passes for a loyal house" do
      expect(house_service.call(house: create(:house))).to be_service_success
    end

    it "fails for a rebellious one" do
      result = house_service.call(house: create(:house, :rebellious))

      expect(result).to be_guard_failure("disloyal_house")
    end

    # Proves the Symbol message went through I18n rather than being used
    # literally — the text below lives in config/locales/en.yml, not in the
    # guard.
    it "resolves its message through I18n with interpolation" do
      house = create(:house, :rebellious, name: "Greyjoy")
      result = house_service.call(house: house)

      expect(result.error.message)
        .to eq("House Greyjoy is rebellious; only loyal houses may move gold")
    end

    it "reports 403 rather than the default 422" do
      result = house_service.call(house: create(:house, :rebellious))

      expect(result.error.http_status).to eq(403)
    end
  end

  # Guards are usually invoked through the generated methods, but they can be
  # run directly. Useful in a policy object or a controller filter that is not
  # itself a service.
  describe "running a guard directly" do
    it "throws :guard_failure from execute! when the test fails" do
      vault = create(:vault, gold_dragons: 1)

      thrown = catch(:guard_failure) do
        Servus::Guard.execute!(SufficientGoldGuard, vault: vault, amount: 999)
        :did_not_throw
      end

      expect(thrown).to be_a(Servus::Support::Errors::GuardError)
      expect(thrown.code).to eq("insufficient_gold")
    end

    it "answers with a boolean from execute?" do
      vault = create(:vault, gold_dragons: 100)

      expect(Servus::Guard.execute?(SufficientGoldGuard, vault: vault, amount: 50)).to be(true)
      expect(Servus::Guard.execute?(SufficientGoldGuard, vault: vault, amount: 999)).to be(false)
    end
  end
end
