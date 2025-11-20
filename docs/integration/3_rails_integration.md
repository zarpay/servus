# @title Integration / 3. Rails Integration

# Rails Integration

Servus core works in any Ruby application. Rails-specific features (async, controller helpers, generators) are optional additions that integrate with Rails conventions.

## Controller Integration

Use the `run_service` helper to call services from controllers with automatic error handling:

```ruby
class UsersController < ApplicationController
  include Servus::Helpers::ControllerHelpers

  def create
    run_service(Users::Create::Service, user_params)
  end

  # Failures automatically render JSON:
  # { "error": { "code": "validation_error", "message": "..." } }
  # with appropriate HTTP status code
  #
  # Success will go to view and service result will be available on @result
end
```

Without the helper, handle responses manually:

```ruby
def create
  result = Users::Create::Service.call(user_params)
  if result.success?
    render json: { user: result.data[:user] }, status: :created
  else
    render json: { error: result.error.api_error }, status: error_status(result.error)
  end
end
```

## Generator

Generate services with specs and schema files:

```bash
rails generate servus:service process_payment

# Creates:
# app/services/process_payment/service.rb
# spec/services/process_payment/service_spec.rb
# app/schemas/services/process_payment/arguments.json
# app/schemas/services/process_payment/result.json
```

Schema files are optional - delete them if you don't need validation.

## Autoloading

Servus follows Rails autoloading conventions. Services in `app/services/` are automatically loaded by Rails:

```ruby
# app/services/users/create/service.rb
module Users
  module Create
    class Service < Servus::Base
      # ...
    end
  end
end

# Rails autoloads this as Users::Create::Service
```

## Configuration

Configure Servus in an initializer if needed:

```ruby
# config/initializers/servus.rb
Servus.configure do |config|
  config.schema_root = Rails.root.join('config/schemas')
end
```

Most applications don't need any configuration.

## Background Jobs

Async execution requires ActiveJob setup. Configure your adapter:

```ruby
# config/application.rb
config.active_job.queue_adapter = :sidekiq
```

Then use `.call_async`:

```ruby
Users::SendWelcomeEmail::Service.call_async(user_id: user.id)
```
