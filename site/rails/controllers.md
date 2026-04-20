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
When a controller action needs to call multiple services and coordinate their results, skip `run_service` and call the services directly:

```ruby
def create
  reserve = Treasury::ReserveFunds::Service.call(**reserve_params)
  return render_service_error(reserve.error) unless reserve.success?

  dispatch = Ravens::DispatchReceipt::Service.call(transfer: reserve.data.transfer_id)
  return render_service_error(dispatch.error) unless dispatch.success?

  render json: { reserve: reserve.data, dispatch: dispatch.data }, status: :created
end
```
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
