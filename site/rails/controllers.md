# Rails Controllers

Rails controllers are one of the clearest places where Servus improves application structure. Instead of assembling business workflows directly in controller actions, the controller can hand off to a named service.

## Controller integration

```ruby
class Api::V1::TreasuryTransfersController < ApiController
  def create
    result = Treasury::TransferGold::Service.call(**transfer_params)

    if result.success?
      render json: result.data, status: :created
    else
      render json: { error: result.error.api_error }, status: result.error.http_status
    end
  end

  private

  def transfer_params
    params.permit(:from_account_id, :to_account_id, :gold_dragons)
  end
end
```

## Why this stays readable

| Controller responsibility | Service responsibility |
| --- | --- |
| Request parsing and response rendering | Business orchestration |
| Authentication and outer HTTP concerns | Domain decisions and business failures |

## Helper-based integration

Servus also provides controller helpers such as `run_service` and `render_service_error`. Those helpers are summarized in the reference section so teams can adopt a lighter controller style without obscuring the core framework pattern.
