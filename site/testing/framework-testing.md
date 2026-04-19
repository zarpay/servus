# Framework Testing

Servus testing should begin with the framework contract itself. A good service spec proves that the service returns the correct response on success, returns the correct failure for expected business-rule violations, and emits any expected events or validations.

## Core testing concerns

| Concern | Example question |
| --- | --- |
| Success path | Does the service return the expected data? |
| Failure path | Does the service fail for the right domain reason? |
| Schema behavior | Are invalid inputs rejected early? |
| Composition | Does the service propagate downstream failures correctly? |
| Events | Are expected events emitted on the correct outcome? |

## Example

```ruby
RSpec.describe Treasury::TransferGold::Service do
  it 'transfers gold successfully' do
    result = described_class.call(
      from_account: crown_account,
      to_account: wall_account,
      gold_dragons: 50
    )

    expect(result).to be_success
    expect(result.data[:ledger_entry][:amount]).to eq(50)
  end

  it 'fails when funds are insufficient' do
    result = described_class.call(
      from_account: empty_account,
      to_account: wall_account,
      gold_dragons: 50
    )

    expect(result).not_to be_success
    expect(result.error.message).to eq('Insufficient funds')
  end
end
```

## Schema helpers

The original Servus testing material also shows how schema examples can seed test data. That is worth preserving because it keeps tests close to the contract rather than duplicating fixture assumptions in many places.
