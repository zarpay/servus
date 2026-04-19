# Production Service Conventions

ZAR Core uses a more opinionated service style than the framework requires by itself. Those conventions are useful because they make large codebases easier to scan, but they should be adopted intentionally rather than mistaken for the baseline Servus mental model.

## Common ZAR conventions

| Convention | Why ZAR uses it | Why it should be framed carefully |
| --- | --- | --- |
| `option` declarations | The contract is visible at the top of the class | This depends on a Dry Initializer overlay rather than the native Servus introduction |
| `schema_key` naming | Schema files are easier to locate and standardize | Useful for mature codebases, but not the only way to use Servus schemas |
| Early `return failure(...)` layout | Business-rule checks stay near the top of `call` | This aligns well with Servus and is a strong general best practice |
| Explicit service composition | Workflow orchestration stays readable | This is a disciplined usage pattern rather than a separate feature |

## Example production-style service

```ruby
module Treasury
  module TransferGold
    class Service < Servus::Base
      schema_key 'services::treasury::transfer_gold'

      option :from_account
      option :to_account
      option :gold_dragons

      def call
        return failure('Amount must be positive') unless gold_dragons.positive?
        return failure('Insufficient funds') if from_account.balance < gold_dragons

        success(transfer: perform_transfer!)
      end
    end
  end
end
```

## Adoption guidance

Teams do not need to start here on day one. A practical path is to learn plain Servus first, adopt framework features deliberately, and then introduce stronger declaration and schema conventions once the service layer becomes large enough for those conventions to repay their cost.
