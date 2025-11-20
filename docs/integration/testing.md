# Testing

Services are designed for easy testing with explicit inputs (arguments) and outputs (Response objects). No special test infrastructure needed.

## Basic Testing Pattern

```ruby
RSpec.describe ProcessPayment::Service do
  describe ".call" do
    let(:user) { create(:user, balance: 1000) }

    subject(:result) { described_class.call(user_id: user.id, amount: amount) }

    context "with sufficient balance" do
      let(:amount) { 50 }

      it "processes payment" do
        expect(result.success?).to be true
        expect(result.data[:new_balance]).to eq(950)
        expect(result.reload.balance).to eq(950)
      end
    end

    context "with insufficient balance" do
      let(:amount) { 2000 }

      it "returns failure" do
        expect(result.success?).to be false
        expect(result.error.message).to eq("Insufficient funds")
        expect(result.error).to be_a(Servus::Support::Errors::ServiceError)
      end
    end
  end
end
```

## Testing Service Composition

When testing services that call other services, mock the child services:

```ruby
describe Users::CreateWithAccount::Service do
  # Make local or global helpers to clean up tests
  def servus_success_result(data)
    Servus::Support::Response.new(success: true, data: data, error: nil)
  end

  it "calls both create services" do
    # Mock child services
    allow(Users::Create::Service).to receive(:call).and_return(servus_success_result{ user: user })
    allow(Accounts::Create::Service).to receive(:call).and_return(servus_success_result{ account: account })

    result = described_class.call(email: "test@example.com", plan: "premium")

    expect(Users::Create::Service).to have_received(:call)
    expect(Accounts::Create::Service).to have_received(:call)

    expect(result.success?).to be true
  end
end
```

## Testing Schema Validation

Don't test that valid arguments pass validation - that's testing the framework. Do test that your schema catches invalid inputs:

```ruby
it "validates required fields" do
  expect {
    Service.call(invalid: "params")
  }.to raise_error(Servus::Support::Errors::ValidationError, /required/)
end
```
