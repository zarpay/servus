# Service Objects

Service objects encapsulate one business operation into a testable, reusable class. They sit between controllers and models, handling orchestration logic that doesn't belong in either.

## The Pattern

Services implement two methods: `initialize` (sets up dependencies) and `call` (executes business logic). All services return a `Response` object indicating success or failure.

```ruby
module Users
  module Create
    class Service < Servus::Base
      def initialize(email:, name:)
        @email = email
        @name = name
      end

      def call
        return failure("Email taken") if User.exists?(email: @email)

        user = User.create!(email: @email, name: @name)
        send_welcome_email(user)

        success(user: user)
      end
    end
  end
end

# Usage
result = Users::Create::Service.call(email: "user@example.com", name: "John")
result.success? # => true
result.data[:user] # => #<User>
```

## Service Composition

Services can call other services. Use the returned Response to decide whether to continue or propagate the failure.

```ruby
def call
  user_result = Users::Create::Service.call(user_params)
  return user_result unless user_result.success? # propogates result failure

  account_result = Accounts::Create::Service.call(
    user: user_result.data[:user],
    plan: @plan
  )
  return account_result unless account_result.success? # propogates result failure

  success(
    user: user_result.data[:user],
    account: account_result.data[:account]
  )
end
```

## When to Extract to Services

**Extract when**:
- Logic spans multiple models
- Complex conditional branching
- External API calls
- Background processing needed
- Testing requires extensive setup

**Don't extract when**:
- Simple CRUD operations
- Single-model updates
- Logic naturally belongs in model

## Directory Structure

Each service lives in its own namespace to avoid naming collisions and allow for support classes.

```
app/services/
├── users/
│   └── create/
│       ├── service.rb
│       └── support/
│           └── welcome_email.rb
└── orders/
    └── process/
        ├── service.rb
        └── support/
            ├── payment_gateway.rb
            └── inventory_updater.rb
```

Support classes are private to their service - they should never be used by other services.

## Testing

Services are designed for easy testing with explicit inputs and outputs.

```ruby
RSpec.describe Users::Create::Service do
  describe ".call" do
    context "with valid params" do
      it "creates user" do
        result = described_class.call(email: "test@example.com", name: "Test")
        expect(result.success?).to be true
        expect(result.data[:user]).to be_persisted
      end
    end

    context "with duplicate email" do
      before { create(:user, email: "test@example.com") }

      it "returns failure" do
        result = described_class.call(email: "test@example.com", name: "Test")
        expect(result.success?).to be false
        expect(result.error.message).to eq("Email taken")
      end
    end
  end
end
```
