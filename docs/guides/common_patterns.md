# Common Patterns

Common architectural patterns for using Servus effectively.

## Parent-Child Services

When one service orchestrates multiple sub-operations, decide on transaction boundaries and error propagation.

```ruby
class Orders::Checkout::Service < Servus::Base
  def call
    ActiveRecord::Base.transaction do
      # Create order
      order_result = Orders::Create::Service.call(order_params)
      return order_result unless order_result.success?

      # Charge payment
      payment_result = Payments::Charge::Service.call(
        user_id: @user_id,
        amount: order_result.data[:order].total
      )
      return payment_result unless payment_result.success?

      # Update inventory
      inventory_result = Inventory::Reserve::Service.call(
        order_id: order_result.data[:order].id
      )
      return inventory_result unless inventory_result.success?

      success(order: order_result.data[:order])
    end
  end
end
```

**Use parent transaction when**: All children must succeed or all roll back (atomic operation)

**Use child transactions when**: Children can succeed independently (partial success acceptable)

## Async with Result Persistence

Store async results in database for later retrieval:

```ruby
# Controller creates placeholder
report = Report.create!(user_id: user.id, status: 'pending')
GenerateReport::Service.call_async(report_id: report.id)

# Service updates record
class GenerateReport::Service < Servus::Base
  def call
    report = Report.find(@report_id)
    data = generate_report_data

    report.update!(data: data, status: 'completed')
    success(report: report)
  end
end
```

## Idempotent Services

Use database constraints to make services idempotent:

```ruby
class Users::Create::Service < Servus::Base
  def call
    # Unique constraint on email prevents duplicates
    user = User.create!(email: @email, name: @name)
    success(user: user)
  rescue ActiveRecord::RecordNotUnique
    user = User.find_by!(email: @email)
    success(user: user)  # Return existing user, not error
  end
end
```

Or check for existing resources explicitly:

```ruby
def call
  existing = User.find_by(email: @email)
  return success(user: existing) if existing

  user = User.create!(email: @email, name: @name)
  success(user: user)
end
```
