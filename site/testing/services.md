# Testing Services

Services are designed to be tested as standalone units — explicit inputs, explicit outputs, no HTTP context, no job infrastructure. Call `.call` with arguments, assert on the `Response`.

## Setup

```ruby
# spec/spec_helper.rb
require 'servus/testing'

RSpec.configure do |config|
  config.include Servus::Testing::ExampleBuilders
end
```

This gives you the schema example helpers and the RSpec matchers.

## Testing a service

### Success path

```ruby
RSpec.describe Treasury::TransferGold::Service do
  let(:from_account) { create(:account, balance: 1000) }
  let(:to_account) { create(:account, balance: 500) }
  let(:gold_dragons) { 50 }

  subject(:result) do
    described_class.call(
      from_account: from_account,
      to_account: to_account,
      gold_dragons: gold_dragons
    )
  end

  it "transfers gold between accounts" do
    expect { result }
      .to change { from_account.reload.balance }.from(1000).to(950)
      .and change { to_account.reload.balance }.from(500).to(550)
  end

  it "returns the transfer details" do
    expect(result).to be_success
    expect(result.data.transferred).to eq(50)
    expect(result.data.from_balance).to eq(950)
    expect(result.data.to_balance).to eq(550)
  end
end
```

No controller setup, no request context, no job queue. The service is a function: arguments in, response out. One test proves the side effects (account balances changed), the other proves the response shape.

Notice the tests only assert on expected values — they don't check types, presence of required fields, or basic validation constraints. That's all statically enforced by the schema before `call` ever runs. Your tests focus on business outcomes, not defensive checks that the schema already guarantees.

### Failure path

Failure tests should prove two things: the side effects didn't happen, and the response carries the right error. Since the `subject` and `let` blocks are already defined, each failure scenario just overrides the inputs that trigger it:

```ruby
describe "when accounts are the same" do
  let(:to_account) { from_account }

  it "does not change any balances" do
    expect { result }
      .to not_change { from_account.reload.balance }
  end

  it "returns an unprocessable entity failure" do
    expect(result).to be_failure
    expect(result.error).to be_a(Servus::Support::Errors::UnprocessableEntityError)
    expect(result.error.message).to eq("Cannot transfer to the same account")
  end
end
```

### Guard failures

```ruby
describe "when the sender account is frozen" do
  let(:from_account) { create(:account, balance: 1000, frozen: true) }

  it "does not change any balances" do
    expect { result }
      .to not_change { from_account.reload.balance }
      .and not_change { to_account.reload.balance }
  end

  it "returns a guard failure" do
    expect(result).to be_failure
    expect(result.error).to be_a(Servus::Support::Errors::GuardError)
    expect(result.error.code).to eq("ineligible_transfer")
  end
end
```

Guard failures produce the same `Response` shape as any other failure — you test them the same way.

## What NOT to test

### Don't test schema validation

The schema is the test. If you defined `gold_dragons: { type: "integer", minimum: 1 }`, you don't need a spec that passes a string and asserts `ValidationError`. The schema already guarantees that — testing it is testing Servus, not your code.

### Don't test the framework lifecycle

Don't assert that logging happened, that the benchmark timer ran, or that `before_call` was invoked. Those are Servus's responsibility. Test your business logic.

## Testing composition

When a service calls other services, the best test is no mock at all — let the full call chain execute. The truest proof that a system works is running the code it will actually run.

When that's not practical (external dependencies, slow operations, complex setup), mock the downstream service's result and assert it was called with the expected arguments. This is the same principle as endpoint testing: you don't make a real network request in your test runner, but you trust the API has a stable request/response shape guaranteed by its schema.

```ruby
RSpec.describe Treasury::SettleLedger::Service do
  let(:ledger) { create(:ledger, entries: 3) }

  subject(:result) { described_class.call(ledger_id: ledger.id) }

  describe "when all transfers succeed" do
    let(:transfer_success) { servus_success_response(transferred: 50) }

    before do
      allow(Treasury::TransferGold::Service)
        .to receive(:call)
        .with(
          from_account: a_kind_of(Integer),
          to_account: a_kind_of(Integer),
          gold_dragons: a_kind_of(Integer)
        )
        .and_return(transfer_success)
    end

    it "calls TransferGold for each entry" do
      result

      expect(Treasury::TransferGold::Service).to have_received(:call).exactly(3).times
    end

    it "returns success" do
      expect(result).to be_success
    end
  end

  describe "when a transfer fails" do
    let(:transfer_failure) { servus_failure_response("Insufficient funds") }

    before do
      allow(Treasury::TransferGold::Service)
        .to receive(:call)
        .and_return(transfer_failure)
    end

    it "propagates the downstream failure" do
      expect(result).to be_failure
      expect(result.error.message).to eq("Insufficient funds")
    end
  end
end
```

## Test helpers

Servus provides two sets of test helpers: **schema example extractors** that pull example values from your schemas, and **response builders** for creating mock responses.

### Response builders

Build `Response` objects without calling the constructor directly:

#### `servus_success_response`

```ruby
servus_success_response(transferred: 50, from_balance: 950, to_balance: 550)
# => Response(success: true, data: { transferred: 50, from_balance: 950, to_balance: 550 })
```

#### `servus_failure_response`

```ruby
servus_failure_response("Insufficient funds")
# => Response(success: false, error: ServiceError("Insufficient funds"))

servus_failure_response("Account not found", type: NotFoundError)
# => Response(success: false, error: NotFoundError("Account not found"))
```

### Schema example extractors

When your schemas include `example` values, these helpers extract them for quick argument hashes and mock responses. Useful for services that handle scalar values and for mocking in other tests. For services that require real records, use factories or fixtures instead — schema examples won't create database records.

```ruby
schema(
  arguments: {
    type: "object",
    properties: {
      from_account: { type: "integer", example: 1 },
      to_account: { type: "integer", example: 2 },
      gold_dragons: { type: "integer", example: 50 }
    }
  },
  result: {
    type: "object",
    properties: {
      transferred: { type: "number", example: 50 },
      from_balance: { type: "number", example: 950 },
      to_balance: { type: "number", example: 550 }
    }
  }
)
```

::: tip examples (plural)
Properties can use `examples: [...]` instead of `example:`. The helper will sample a random value from the array each time:

```ruby
gold_dragons: { type: "integer", examples: [50, 75, 100] }

servus_arguments_example(Treasury::TransferGold::Service)
# => { ..., gold_dragons: 75 }  (randomly sampled)
```
:::

#### `servus_arguments_example`

Extracts argument examples, with optional overrides:

```ruby
args = servus_arguments_example(Treasury::TransferGold::Service)
# => { from_account: 1, to_account: 2, gold_dragons: 50 }

args = servus_arguments_example(Treasury::TransferGold::Service, gold_dragons: 100)
# => { from_account: 1, to_account: 2, gold_dragons: 100 }
```

Overrides are deep-merged, so you can override nested values without rebuilding the whole hash:

```ruby
args = servus_arguments_example(
  Ravens::DispatchMessage::Service,
  destination: { castle: "Winterfell", urgency: :critical }
)
# => { rookery: 1, destination: { castle: "Winterfell", region: "North", urgency: :critical } }
#    ↑ region came from the schema example, urgency was overridden
```

#### `servus_result_example`

Returns a successful `Response` with result examples — useful for mocking a service in other tests:

```ruby
expected = servus_result_example(Treasury::TransferGold::Service)
# => Response(success: true, data: { transferred: 50, from_balance: 950, to_balance: 550 })

allow(Treasury::TransferGold::Service).to receive(:call).and_return(expected)
```

#### `servus_failure_example`

Returns a failure `Response` with failure schema examples:

```ruby
expected = servus_failure_example(Treasury::TransferGold::Service)
# => Response(success: false, data: { reason: "insufficient_funds" })

allow(Treasury::TransferGold::Service).to receive(:call).and_return(expected)
```

## Event matchers

These matchers test that a **service emits the expected events** — they don't test event handler behavior. For testing handlers, see [Testing Events](/testing/events).

### `emit_event`

Assert that a service emits an event:

```ruby
it "emits gold_transferred on success" do
  expect {
    described_class.call(
      from_account: from_account,
      to_account: to_account,
      gold_dragons: 50
    )
  }.to emit_event(:gold_transferred)
end
```

Assert the event payload:

```ruby
it "emits gold_transferred with the transfer amount" do
  expect {
    described_class.call(
      from_account: from_account,
      to_account: to_account,
      gold_dragons: 50
    )
  }.to emit_event(:gold_transferred).with(hash_including(transferred: 50))
end
```

You can also pass a handler class instead of a symbol:

```ruby
expect {
  described_class.call(
    from_account: from_account,
    to_account: to_account,
    gold_dragons: 50
  )
}.to emit_event(GoldTransferredHandler)
```

