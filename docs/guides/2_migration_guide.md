# @title Guides / 2. Migration Guide

# Migration Guide

Strategies for adopting Servus in existing Rails applications, and version-specific migration notes.

## Migrating to 0.3.0

### Breaking: `result.data` is no longer guaranteed nil on failure

In 0.2.x, `failure()` always set `result.data` to `nil`. Some code relied on this to distinguish success from failure:

```ruby
# ❌ Unsafe in 0.3.0 — result.data can be non-nil on failure
if result.data
  # handle success
else
  # handle failure
end
```

In 0.3.0, `failure()` accepts an optional `data:` kwarg, so failure responses can carry structured data. Use `result.success?` or `result.failure?` instead:

```ruby
# ✅ Correct — always use success? or failure?
if result.success?
  render json: result.data, status: :ok
else
  render json: { error: result.error.api_error, details: result.data }, status: result.error.http_status
end
```

**How to find affected code**: Search your codebase for patterns like `if result.data`, `result.data.present?`, or `result.data.nil?` used as success/failure checks. Replace them with `result.success?` or `result.failure?`.

### Removed: `Response#with_data`

`with_data` was removed in favor of the `data:` kwarg on `failure()`:

```ruby
# ❌ 0.2.x — no longer available
failure("Declined").tap { |r| r.with_data(reason: "insufficient_funds") }

# ✅ 0.3.0
failure("Declined", data: { reason: "insufficient_funds" })
```

### New: DataObject wrapping

Response data is now wrapped in a `DataObject` when it is a Hash. This is backwards compatible — `result.data[:key]` still works. You can also use accessor-style access:

```ruby
result.data[:user]       # still works
result.data.user         # also works (new)
result.data.user.email   # nested access (new)
```

## Incremental Adoption

Servus coexists with existing code - no need to rewrite your entire application. Start with one complex use case, validate the pattern works for your team, then expand gradually.

## Extracting from Fat Controllers

Identify controller actions with complex business logic and extract to services:

**Before**:
```ruby
class OrdersController < ApplicationController
  def create
    # 50 lines of business logic
    # Multiple model operations
    # External API calls
    # Email sending
  end
end
```

**After**:
```ruby
class OrdersController < ApplicationController
  def create
    result = Orders::Create::Service.call(order_params)
    if result.success?
      render json: { order: result.data[:order] }, status: :created
    else
      render json: { error: result.error.api_error }, status: :unprocessable_entity
    end
  end
end

# Or use the helper
class OrdersController < ApplicationController
  include Servus::Helpers::ControllerHelpers

  def create
    run_service(Orders::Create::Service, order_params) do |result|
      render json: { order: result.data[:order] }, status: :created
    end
  end
end
```

## Extracting from Fat Models

Move orchestration logic from models to services. Keep data-related methods in models:

**Before**:
```ruby
class Order < ApplicationRecord
  def complete_purchase
    charge_payment
    update_inventory
    send_confirmation_email
    create_invoice
  end
end
```

**After**:
```ruby
class Order < ApplicationRecord
  # Model focuses on data
  validates :total, presence: true
  belongs_to :user
end

class Orders::CompletePurchase::Service < Servus::Base
  # Service handles orchestration
  def initialize(order_id:)
    @order_id = order_id
  end

  def call
    order = Order.find(@order_id)
    Payments::Charge::Service.call(order_id: order.id)
    Inventory::Update::Service.call(order_id: order.id)
    Mailers::SendConfirmation::Service.call(order_id: order.id)
    success(order: order)
  end
end
```

## Replacing Callbacks

Extract callback logic to explicit service calls:

**Before**:
```ruby
class User < ApplicationRecord
  after_create :send_welcome_email
  after_create :create_default_account
  after_update :notify_changes, if: :email_changed?
end
```

**After**:
```ruby
class User < ApplicationRecord
  # Minimal or no callbacks
end

class Users::Create::Service < Servus::Base
  def call
    user = User.create!(params)
    send_welcome_email(user)
    create_default_account(user)
    success(user: user)
  end
end
```

## Migrating Background Jobs

Extract job logic to services, call via `.call_async`:

**Before**:
```ruby
class ProcessOrderJob < ApplicationJob
  def perform(order_id)
    # 50 lines of business logic
  end
end

ProcessOrderJob.perform_later(order.id)
```

**After**:
```ruby
class Orders::Process::Service < Servus::Base
  def initialize(order_id:)
    @order_id = order_id
  end

  def call
    # Business logic
  end
end

Orders::Process::Service.call_async(order_id: order.id)
```

Now the service can be called synchronously (from console, tests) or asynchronously (from controllers, jobs).

## Testing During Migration

Keep existing tests working while adding service tests:

```ruby
# Keep existing controller test
describe OrdersController do
  it "creates order" do
    post :create, params: params
    expect(response).to be_successful
  end
end

# Add service test
describe Orders::Create::Service do
  it "creates order" do
    result = described_class.call(params)
    expect(result.success?).to be true
  end
end
```

Remove legacy tests after service tests prove comprehensive.
