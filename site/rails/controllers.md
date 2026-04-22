# Controllers

Servus provides controller helpers that eliminate the success/failure branching boilerplate. The Railtie auto-includes `Servus::Helpers::ControllerHelpers` into all controllers — no setup needed.

## `run_service`

`run_service` calls the service, stores the result in `@result`, and automatically renders a JSON error response on failure. It also returns the result, so you can branch on it:

```ruby
class Api::V1::TreasuryTransfersController < ApiController
  def create
    result = run_service(Treasury::TransferGold::Service, transfer_params)
    return unless result.success?

    render json: result.data, status: :created
  end

  private

  def transfer_params
    params.permit(:from_account, :to_account, :gold_dragons)
  end
end
```

On failure, the controller renders the error automatically using the error's `http_status` and `api_error`:

```json
// failure("Account not found", type: NotFoundError)
// renders with status 404:
{
  "error": {
    "code": "not_found",
    "message": "Account not found"
  }
}
```

This is where typed errors pay off — a `failure` with `type: NotFoundError` becomes a 404, `type: ForbiddenError` becomes a 403, and so on. The controller doesn't interpret the failure; the error type carries its own HTTP semantics.

`@result` is always set — on both success and failure. Use it in views, serializers, or anywhere in the request lifecycle after `run_service` is called.

::: tip Orchestrating multiple services
When a controller action needs multiple services, compose them *inside a service* using [`call!`](/core/composition) rather than orchestrating in the controller. The controller stays thin — one service, one `run_service` — and the orchestration lives where it can be tested and reused:

```ruby
# app/services/treasury/reserve_and_dispatch/service.rb
module Treasury
  module ReserveAndDispatch
    class Service < Servus::Base
      def initialize(**reserve_params)
        @reserve_params = reserve_params
      end

      def call
        reserve  = call!(Treasury::ReserveFunds::Service, **@reserve_params)
        dispatch = call!(Ravens::DispatchReceipt::Service, transfer: reserve.transfer_id)

        success(reserve: reserve, dispatch: dispatch)
      end
    end
  end
end

# app/controllers/api/v1/treasury_transfers_controller.rb
def create
  result = run_service(Treasury::ReserveAndDispatch::Service, reserve_params)
  return unless result.success?

  render json: result.data, status: :created
end
```

If either sub-service fails, `call!` halts the composer with the original failure `Response` — `run_service` then renders the correct HTTP status automatically.
:::

## Using `@result` in views

On success, `@result` holds the response. Use it in your view or serializer:

```ruby
class Api::V1::TreasuryTransfersController < ApiController
  def create
    run_service(Treasury::TransferGold::Service, transfer_params)
  end

  # app/views/api/v1/treasury_transfers/create.json.jbuilder
  # json.transferred @result.data.transferred
  # json.from_balance @result.data.from_balance
  # json.to_balance @result.data.to_balance
end
```

Or render inline:

```ruby
def create
  result = run_service(Treasury::TransferGold::Service, transfer_params)
  return unless result.success?

  render json: @result.data, status: :created
end
```

## `run_service!`

Bang counterpart to `run_service`. Returns the service's data on success and raises the failure's error otherwise — no rendering, no `@result`. Use it in paths where an exception is preferable to a JSON response, such as webhook receivers or endpoints where a failure is a bug:

```ruby
class WebhooksController < ApplicationController
  def stripe
    event = Stripe::Webhook.construct_event(request.body.read, signature, secret)

    run_service!(Payments::RecordWebhook::Service, event: event)

    head :ok
  end
end
```

Inside a service's `#call` method, reach for [`call!`](/core/composition) instead — it preserves the failure `Response` for the outer service's caller rather than raising.

## `render_service_error`

`run_service` delegates failure rendering to `render_service_error`, which you can override to customize the error response format:

```ruby
class ApplicationController < ActionController::Base
  private

  def render_service_error(error)
    render json: {
      error: {
        type: error.api_error[:code],
        message: error.message,
        timestamp: Time.current
      }
    }, status: error.http_status
  end
end
```

The default implementation renders `{ error: error.api_error }` with `error.http_status`.
