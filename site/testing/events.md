# Testing Events

Event testing covers two things separately: that a service emits the right events, and that an Event class invokes the right services when an event fires. Testing them independently means you can refactor either side with clear feedback about what changed.

## Testing that a service emits events

Use the `emit_event` matcher to assert a service emits an event on success or failure:

```ruby
RSpec.describe Treasury::TransferGold::Service do
  let(:from_account) { create(:account, balance: 1000) }
  let(:to_account) { create(:account, balance: 500) }

  it "emits gold_transferred on success" do
    expect {
      described_class.call(
        from_account: from_account,
        to_account: to_account,
        gold_dragons: 50
      )
    }.to emit_event(:gold_transferred_event)
  end

  it "emits with the transfer amount in the payload" do
    expect {
      described_class.call(
        from_account: from_account,
        to_account: to_account,
        gold_dragons: 50
      )
    }.to emit_event(:gold_transferred_event).with(hash_including(transferred: 50))
  end
end
```

You can also pass an Event class instead of a symbol:

```ruby
expect {
  described_class.call(
    from_account: from_account,
    to_account: to_account,
    gold_dragons: 50
  )
}.to emit_event(GoldTransferredEvent)
```

## Testing Event classes

Event classes are tested by calling their `handle` class method with a payload. Use the `call_service` matcher to assert which services are invoked:

```ruby
RSpec.describe GoldTransferredEvent do
  let(:payload) do
    {
      transferred: 50,
      from_balance: 950,
      to_balance: 550
    }
  end

  it "invokes Ledger::RecordEntry" do
    expect {
      described_class.handle(payload)
    }.to call_service(Ledger::RecordEntry::Service)
  end

  it "invokes it asynchronously" do
    expect {
      described_class.handle(payload)
    }.to call_service(Ledger::RecordEntry::Service).async
  end

  it "invokes it with the expected arguments" do
    expect {
      described_class.handle(payload)
    }.to call_service(Ledger::RecordEntry::Service).with(
      transferred: payload[:transferred]
    )
  end
end
```

### Chaining

`.async` and `.with` can be combined:

```ruby
expect {
  described_class.handle(payload)
}.to call_service(Ravens::SendReceipt::Service)
  .with(amount: 50)
  .async
```

## Testing conditional invocations

When an Event class uses `if:` or `unless:` conditions, test both paths:

```ruby
RSpec.describe GoldTransferredEvent do
  context "when transfer exceeds 100 gold dragons" do
    let(:payload) { { transferred: 150, from_balance: 850, to_balance: 650 } }

    it "dispatches a raven" do
      expect {
        described_class.handle(payload)
      }.to call_service(Ravens::DispatchMessage::Service).async
    end
  end

  context "when transfer is 100 or less" do
    let(:payload) { { transferred: 50, from_balance: 950, to_balance: 550 } }

    it "does not dispatch a raven" do
      expect {
        described_class.handle(payload)
      }.not_to call_service(Ravens::DispatchMessage::Service)
    end
  end
end
```
