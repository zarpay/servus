# frozen_string_literal: true

# =============================================================================
# Factories
# =============================================================================
#
# Deliberately plain. In the `amounts` demo the factories double as a catalog
# of every input shape the gem accepts, because that gem's surface IS the
# casting of values.
#
# Servus's surface is the service layer, so its equivalent catalog lives in the
# service specs instead. These factories exist only to give those specs realistic
# records to act on. Traits cover the states guards care about.
FactoryBot.define do
  factory :house do
    sequence(:name) { |n| "House #{n}" }
    sigil { "direwolf" }
    standing { "loyal" }
    attainted { false }

    # StateGuard rejects this standing.
    trait :rebellious do
      standing { "rebellious" }
    end

    # TruthyGuard rejects a house in this state.
    trait :attainted do
      attainted { true }
    end

    trait :with_vault do
      after(:create) { |house| create(:vault, house: house) }
    end
  end

  factory :vault do
    house
    gold_dragons { 1_000 }
    sealed { false }

    # FalseyGuard rejects a sealed vault.
    trait :sealed do
      sealed { true }
    end

    trait :empty do
      gold_dragons { 0 }
    end
  end

  factory :ledger_entry do
    vault
    amount { 50 }
    direction { "debit" }
    memo { "test entry" }
  end

  factory :raven do
    house
    message { "Winter is coming" }
    destination { "kings_landing" }
  end
end
