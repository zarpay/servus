# @title Integration / 2. Testing

# Testing

Services are designed for easy testing with explicit inputs (arguments) and outputs (Response objects). No special test infrastructure needed.

## Schema Example Helpers

Servus provides test helpers that extract `example` values from your JSON schemas, making it easy to generate test fixtures without maintaining separate factories.

### Setup

Include the helpers in your test suite:

```ruby
# spec/spec_helper.rb
require 'servus/testing'

RSpec.configure do |config|
  config.include Servus::Testing::ExampleBuilders
end
```

### Using Schema Examples

Add `example` or `examples` keywords to your schemas:

```ruby
class ProcessPayment::Service < Servus::Base
  schema(
    arguments: {
      type: "object",
      properties: {
        user_id: { type: "integer", example: 123 },
        amount: { type: "number", example: 100.0 },
        currency: { type: "string", examples: ["USD", "EUR", "GBP"] }
      }
    },
    result: {
      type: "object",
      properties: {
        transaction_id: { type: "string", example: "txn_abc123" },
        status: { type: "string", example: "approved" }
      }
    }
  )
end
```

Then use the helpers in your tests:

```ruby
RSpec.describe ProcessPayment::Service do
  it "processes payment successfully" do
    # Extract examples from schema and override specific values
    args = servus_arguments_example(ProcessPayment::Service, amount: 50.0)
    # => { user_id: 123, amount: 50.0, currency: "USD" }

    result = ProcessPayment::Service.call(**args)

    expect(result).to be_success
    expect(result.data.keys).to match_array(
      servus_result_example(ProcessPayment::Service).data.keys
    )
  end

  it "handles different currencies" do
    %w[USD EUR GBP].each do |currency|
      result = ProcessPayment::Service.call(
        **servus_arguments_example(ProcessPayment::Service, currency: currency)
      )
      expect(result).to be_success
    end
  end
end
```

### Deep Merging

Overrides are deep-merged with schema examples, allowing you to override nested values:

```ruby
# Schema has nested structure
args = servus_arguments_example(
  CreateUser::Service,
  user: { profile: { age: 35 } }
)
# => { user: { id: 1, profile: { name: 'Alice', age: 35 } } }
```

### Available Helpers

- `servus_arguments_example(ServiceClass, **overrides)` - Returns hash of argument examples
- `servus_result_example(ServiceClass, **overrides)` - Returns Response object with result examples

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

## Testing Event Emission

Servus provides RSpec matchers for testing that services emit events.

### Setup

Include the matchers in your test suite:

```ruby
# spec/spec_helper.rb
require 'servus/testing'
```

### emit_event Matcher

Assert that a block emits an event:

```ruby
RSpec.describe CreateUser::Service do
  it 'emits user_created event on success' do
    expect {
      described_class.call(email: 'test@example.com', name: 'Test')
    }.to emit_event(:user_created)
  end

  it 'emits event with expected payload' do
    expect {
      described_class.call(email: 'test@example.com', name: 'Test')
    }.to emit_event(:user_created).with(hash_including(email: 'test@example.com'))
  end

  # Using handler class instead of symbol
  it 'emits to UserCreatedHandler' do
    expect {
      described_class.call(email: 'test@example.com', name: 'Test')
    }.to emit_event(UserCreatedHandler)
  end
end
```

### call_service Matcher

Assert that a handler invokes a service:

```ruby
RSpec.describe UserCreatedHandler do
  let(:payload) { { user_id: 123, email: 'test@example.com' } }

  it 'invokes SendWelcomeEmail::Service' do
    expect {
      described_class.handle(payload)
    }.to call_service(SendWelcomeEmail::Service).with(user_id: 123)
  end

  it 'invokes service asynchronously' do
    expect {
      described_class.handle(payload)
    }.to call_service(SendWelcomeEmail::Service).async
  end
end
```

### Testing EventHandler Directly

Test handlers by calling their `handle` class method:

```ruby
RSpec.describe UserCreatedHandler do
  let(:payload) { { user_id: 123, email: 'test@example.com' } }

  before do
    allow(SendWelcomeEmail::Service).to receive(:call_async)
    allow(TrackAnalytics::Service).to receive(:call_async)
  end

  it 'invokes SendWelcomeEmail with mapped arguments' do
    described_class.handle(payload)

    expect(SendWelcomeEmail::Service)
      .to have_received(:call_async)
      .with(user_id: 123, email: 'test@example.com')
  end

  it 'invokes TrackAnalytics with event data' do
    described_class.handle(payload)

    expect(TrackAnalytics::Service)
      .to have_received(:call_async)
      .with(event: 'user_created', user_id: 123)
  end

  context 'with conditional invocation' do
    it 'skips premium rewards for non-premium users' do
      allow(GrantPremiumRewards::Service).to receive(:call)

      described_class.handle(payload.merge(premium: false))

      expect(GrantPremiumRewards::Service).not_to have_received(:call)
    end
  end
end
```

### Testing Event Emission from Handler

Test the `emit` class method:

```ruby
RSpec.describe UserCreatedHandler do
  it 'emits the user_created event' do
    expect {
      described_class.emit({ user_id: 123, email: 'test@example.com' })
    }.to emit_event(:user_created)
  end

  it 'validates payload against schema' do
    expect {
      described_class.emit({ invalid: 'payload' })
    }.to raise_error(Servus::Support::Errors::ValidationError)
  end
end
```
