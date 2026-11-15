# Dry Initializer

[dry-initializer](https://dry-rb.org/gems/dry-initializer/) replaces manual `initialize` methods with a declarative `option` DSL. It pairs well with Servus — services become shorter, kwargs get type coercion and defaults, and the boilerplate of assigning instance variables disappears.

## Before and after

### Without dry-initializer

```ruby
module Treasury
  module TransferGold
    class Service < Servus::Base
      lazily :from_account, finds: Account
      lazily :to_account, finds: Account

      def initialize(from_account:, to_account:, gold_dragons:)
        @from_account = from_account
        @to_account = to_account
        @gold_dragons = gold_dragons
      end

      def call
        from_account.withdraw!(@gold_dragons)
        to_account.deposit!(@gold_dragons)

        success(
          transferred: @gold_dragons,
          from_balance: from_account.balance,
          to_balance: to_account.balance
        )
      end
    end
  end
end
```

### With dry-initializer

```ruby
module Treasury
  module TransferGold
    class Service < Servus::Base
      option :from_account
      option :to_account
      option :gold_dragons, default: -> { 1 }

      lazily :from_account, finds: Account
      lazily :to_account, finds: Account

      def call
        from_account.withdraw!(gold_dragons)
        to_account.deposit!(gold_dragons)

        success(
          transferred: gold_dragons,
          from_balance: from_account.balance,
          to_balance: to_account.balance
        )
      end
    end
  end
end
```

No `initialize`, no `@instance_variables`, no manual assignment. Each `option` declares a keyword argument and creates an accessor with optional defaults. Inside `call`, you use `gold_dragons` instead of `@gold_dragons`.

## Installation

Add the gem:

```ruby
gem 'dry-initializer'
```

```bash
bundle install
```

## Setting up an ApplicationService

Create a base class that includes dry-initializer for all services:

```ruby
# app/services/application_service.rb
class ApplicationService < Servus::Base
  extend Dry::Initializer
end
```

Then inherit from it:

```ruby
module Treasury
  module TransferGold
    class Service < ApplicationService
      option :from_account
      option :to_account
      option :gold_dragons

      lazily :from_account, finds: Account
      lazily :to_account, finds: Account

      def call
        # ...
      end
    end
  end
end
```

## `option` features

dry-initializer's `option` supports types, defaults, and coercion:

```ruby
class Service < ApplicationService
  option :from_account
  option :to_account
  option :gold_dragons, default: -> { 0 }
  option :currency, default: -> { "gold_dragons" }
  option :note, optional: true
end
```

| Feature | Example | What it does |
| --- | --- | --- |
| Required by default | `option :from_account` | Raises `KeyError` if not provided |
| Default value | `option :gold_dragons, default: -> { 0 }` | Uses the proc's return value when omitted |
| Optional | `option :note, optional: true` | `nil` when omitted, no error |

## Compatibility with `lazily`

`lazily` works alongside dry-initializer. The resolver defines its accessor on a prepended module, which takes priority over dry-initializer's generated method. It reads from the `@name` instance variable that dry-initializer sets:

```ruby
class Service < ApplicationService
  option :from_account
  option :to_account
  option :gold_dragons

  lazily :from_account, finds: Account
  lazily :to_account, finds: Account

  def call
    # from_account is resolved by lazily, not dry-initializer's reader
    # gold_dragons uses dry-initializer's reader directly
    success(transferred: gold_dragons)
  end
end
```

Both `option` and `lazily` declare `:from_account`, but `lazily`'s accessor takes precedence. The `option` declaration still handles the initialization — `lazily` just intercepts the read.