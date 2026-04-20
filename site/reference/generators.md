# Generators Reference

Full reference for all Servus Rails generators — commands, arguments, options, and generated output.

## `servus:service`

Generates a service class, spec, and JSON schema files.

```bash
rails g servus:service treasury/transfer_gold from_account to_account gold_dragons

=> create  app/services/treasury/transfer_gold/service.rb
=> create  spec/services/treasury/transfer_gold/service_spec.rb
=> create  app/schemas/services/treasury/transfer_gold/result.json
=> create  app/schemas/services/treasury/transfer_gold/arguments.json
```

| Argument | Required | Description |
| --- | --- | --- |
| `name` | Yes | Namespaced service name (e.g., `treasury/transfer_gold`) |
| `parameters` | No | Space-separated list of keyword arguments (e.g., `from_account to_account gold_dragons`) |

| Option | Description |
| --- | --- |
| `--no-docs` | Skip YARD documentation comments and TODO scaffolding |

### Generated service

With parameters:

```ruby
# app/services/treasury/transfer_gold/service.rb
module Treasury::TransferGold
  class Service < Servus::Base
    def initialize(from_account:, to_account:, gold_dragons:)
      @from_account = from_account
      @to_account = to_account
      @gold_dragons = gold_dragons
    end

    def call
      # TODO: Implement service logic here
      success({})
    end

    private

    attr_reader :from_account, :to_account, :gold_dragons
  end
end
```

Without parameters:

```ruby
# app/services/treasury/transfer_gold/service.rb
module Treasury::TransferGold
  class Service < Servus::Base
    def initialize
      # TODO: Initialize instance variables
    end

    def call
      # TODO: Implement service logic here
      success({})
    end

    private

    # TODO: Add attr_readers for instance variables
  end
end
```

### Generated spec

```ruby
# spec/services/treasury/transfer_gold/service_spec.rb
RSpec.describe Treasury::TransferGold::Service do
  let(:from_account) { nil } # TODO: Set valid test value
  let(:to_account) { nil }   # TODO: Set valid test value
  let(:gold_dragons) { nil }  # TODO: Set valid test value

  describe '#call' do
    # TODO: Add success and failure tests
  end
end
```

### Generated schemas

Arguments schema with the parameters declared as required:

```json
// app/schemas/services/treasury/transfer_gold/arguments.json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Treasury::TransferGold Arguments",
  "type": "object",
  "properties": {
    "from_account": { "type": "string", "description": "TODO" },
    "to_account": { "type": "string", "description": "TODO" },
    "gold_dragons": { "type": "string", "description": "TODO" }
  },
  "required": ["from_account", "to_account", "gold_dragons"],
  "additionalProperties": false
}
```

Result schema (empty, ready to fill in):

```json
// app/schemas/services/treasury/transfer_gold/result.json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Treasury::TransferGold Result",
  "type": "object",
  "properties": {},
  "required": [],
  "additionalProperties": true
}
```

::: tip Inline schemas preferred
The generator creates JSON schema files for convenience, but the `schema` DSL is the recommended approach. You can delete the JSON files and define schemas inline — see [Schema Validation](/features/schema-validation).
:::

### Destroy

```bash
rails d servus:service treasury/transfer_gold
```

---

## `servus:event_handler`

Generates an event handler class and spec.

```bash
rails g servus:event_handler gold_transferred

=> create  app/events/gold_transferred_handler.rb
=> create  spec/app/events/gold_transferred_handler_spec.rb
```

| Argument | Required | Description |
| --- | --- | --- |
| `name` | Yes | Event name in snake_case (e.g., `gold_transferred`) |

| Option | Description |
| --- | --- |
| `--no-docs` | Skip YARD documentation comments and TODO scaffolding |

### Generated handler

```ruby
# app/events/gold_transferred_handler.rb
class GoldTransferredHandler < Servus::EventHandler
  handles :gold_transferred

  schema payload: {
    type: 'object',
    description: 'JSON schema for the GoldTransferredHandler event payload',
  }

  # invoke ExampleService, async: true do |payload|
  #   { example_arg: payload[:example_field] }
  # end
end
```

### Generated spec

```ruby
# spec/app/events/gold_transferred_handler_spec.rb
RSpec.describe GoldTransferredHandler do
  let(:payload) do
    {
      # TODO: Add sample payload fields
    }
  end

  # TODO: Add tests for service invocations
end
```

### Destroy

```bash
rails d servus:event_handler gold_transferred
```

---

## `servus:guard`

Generates a guard class and spec.

```bash
rails g servus:guard eligible_transfer

=> create  app/guards/eligible_transfer_guard.rb
=> create  spec/guards/eligible_transfer_guard_spec.rb
```

| Argument | Required | Description |
| --- | --- | --- |
| `name` | Yes | Guard name in snake_case, without the `Guard` suffix (e.g., `eligible_transfer`) |

| Option | Description |
| --- | --- |
| `--no-docs` | Skip YARD documentation comments and TODO scaffolding |

### Generated guard

```ruby
# app/guards/eligible_transfer_guard.rb
class EligibleTransferGuard < Servus::Guard
  http_status 422
  error_code 'eligible_transfer'

  message '%<class_name>s eligible transfer validation failed' do
    message_data
  end

  def test(**kwargs)
    # TODO: Implement validation logic
    true
  end

  private

  def message_data
    # TODO: Return hash of values for message interpolation
    { class_name: 'Object' }
  end
end
```

### Generated spec

```ruby
# spec/guards/eligible_transfer_guard_spec.rb
RSpec.describe EligibleTransferGuard do
  describe '#test' do
    it 'returns true when validation passes' do
      guard = described_class.new
      expect(guard.test).to be true
    end
  end

  describe '#error' do
    it 'returns a GuardError with correct metadata' do
      guard = described_class.new
      error = guard.error

      expect(error).to be_a(Servus::Support::Errors::GuardError)
      expect(error.code).to eq('eligible_transfer')
      expect(error.http_status).to eq(422)
    end
  end

  describe 'method registration' do
    it 'defines enforce_eligible_transfer! on Servus::Guards' do
      expect(Servus::Guards.method_defined?(:enforce_eligible_transfer!)).to be true
    end

    it 'defines check_eligible_transfer? on Servus::Guards' do
      expect(Servus::Guards.method_defined?(:check_eligible_transfer?)).to be true
    end
  end
end
```

### Destroy

```bash
rails d servus:guard eligible_transfer
```

---

## Configuration

All generators respect the directory settings in `Servus.configure`:

```ruby
# config/initializers/servus.rb
Servus.configure do |config|
  config.services_dir = "app/services"  # default: "app/services"
  config.schemas_dir  = "app/schemas"   # default: "app/schemas"
  config.events_dir   = "app/events"    # default: "app/events"
  config.guards_dir   = "app/guards"    # default: "app/guards"
end
```

See [Configuration](/rails/configuration) for all options.
