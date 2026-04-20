# Testing Guards

Guards are standalone classes with a single `test` method — they're straightforward to test in isolation. A guard spec should prove the validation logic and the error metadata.

## Testing the validation logic

```ruby
RSpec.describe EligibleTransferGuard do
  let(:open_account) { build(:account, status: :open, frozen: false, balance: 1000) }
  let(:to_account) { build(:account, status: :open, frozen: false, balance: 500) }
  let(:amount) { 50 }

  subject(:guard) { described_class.new(from: from_account, to: to_account, amount: amount) }

  describe "#test" do
    context "when both accounts are eligible" do
      let(:from_account) { open_account }

      it "passes" do
        expect(guard.test).to be true
      end
    end

    context "when the sender account is closed" do
      let(:from_account) { build(:account, status: :closed, frozen: false, balance: 1000) }

      it "fails" do
        expect(guard.test).to be false
      end
    end

    context "when the sender account is frozen" do
      let(:from_account) { build(:account, status: :open, frozen: true, balance: 1000) }

      it "fails" do
        expect(guard.test).to be false
      end
    end

    context "when balance is insufficient" do
      let(:from_account) { build(:account, status: :open, frozen: false, balance: 0) }

      it "fails" do
        expect(guard.test).to be false
      end
    end
  end
end
```

## Testing the error metadata

When a guard fails, the error carries a code and message. Test these to ensure callers and controllers receive the right response:

```ruby
describe "#error" do
  let(:from_account) { build(:account, status: :open, frozen: true, balance: 1000) }

  it "returns a GuardError with the correct code" do
    expect(guard.error).to be_a(Servus::Support::Errors::GuardError)
    expect(guard.error.code).to eq("ineligible_transfer")
  end

  it "includes a descriptive message" do
    expect(guard.error.message).to include("frozen")
  end
end
```

Always test guards in isolation. A guard that's tested through the service it happens to live in today can't be reused confidently tomorrow. Isolated guard specs prove the rule works regardless of which service calls it — that's the whole point of extracting the rule into a guard in the first place.
