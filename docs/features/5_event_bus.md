# @title Features / 5. Event Bus

# Event Bus

Servus includes an event-driven architecture for decoupling service logic from side effects. Services emit events, and EventHandlers subscribe to them and invoke downstream services.

## Overview

The Event Bus provides:
- **Emitters**: Services declare events they emit on success/failure
- **EventHandlers**: Subscribe to events and invoke services in response
- **Event Bus**: Routes events to registered handlers via ActiveSupport::Notifications
- **Payload Validation**: Optional JSON Schema validation for event payloads

## Service Event Emission

Services can emit events when they succeed or fail using the `emits` DSL:

```ruby
class CreateUser::Service < Servus::Base
  emits :user_created, on: :success
  emits :user_creation_failed, on: :failure

  def initialize(email:, name:)
    @email = email
    @name = name
  end

  def call
    user = User.create!(email: @email, name: @name)
    success(user: user)
  rescue ActiveRecord::RecordInvalid => e
    failure(e.message)
  end
end
```

### Custom Payloads

By default, success events receive `result.data` and failure events receive `result.error`. Customize with a block or method:

```ruby
class CreateUser::Service < Servus::Base
  # Block-based payload
  emits :user_created, on: :success do |result|
    { user_id: result.data[:user].id, email: result.data[:user].email }
  end

  # Method-based payload
  emits :user_stats_updated, on: :success, with: :stats_payload

  private

  def stats_payload(result)
    { user_count: User.count, latest_user_id: result.data[:user].id }
  end
end
```

### Trigger Types

- `:success` - Fires when service returns `success(...)`
- `:failure` - Fires when service returns `failure(...)`
- `:error!` - Fires when service calls `error!(...)` (before exception is raised)

## Event Handlers

EventHandlers live in `app/events/` and subscribe to events using a declarative DSL:

```ruby
# app/events/user_created_handler.rb
class UserCreatedHandler < Servus::EventHandler
  handles :user_created

  invoke SendWelcomeEmail::Service, async: true do |payload|
    { user_id: payload[:user_id], email: payload[:email] }
  end

  invoke TrackAnalytics::Service, async: true do |payload|
    { event: 'user_created', user_id: payload[:user_id] }
  end
end
```

### Generator

Generate handlers with the Rails generator:

```bash
rails g servus:event_handler user_created
# Creates:
#   app/events/user_created_handler.rb
#   spec/events/user_created_handler_spec.rb
```

### Invocation Options

```ruby
class UserCreatedHandler < Servus::EventHandler
  handles :user_created

  # Synchronous invocation (default)
  invoke NotifyAdmin::Service do |payload|
    { message: "New user: #{payload[:email]}" }
  end

  # Async via ActiveJob
  invoke SendWelcomeEmail::Service, async: true do |payload|
    { user_id: payload[:user_id] }
  end

  # Async with specific queue
  invoke SendWelcomeEmail::Service, async: true, queue: :mailers do |payload|
    { user_id: payload[:user_id] }
  end

  # Conditional invocation
  invoke GrantPremiumRewards::Service, if: ->(p) { p[:premium] } do |payload|
    { user_id: payload[:user_id] }
  end

  invoke SkipForPremium::Service, unless: ->(p) { p[:premium] } do |payload|
    { user_id: payload[:user_id] }
  end
end
```

## Emitting Events Directly

EventHandlers provide an `emit` class method for emitting events from controllers, jobs, or other code without a service:

```ruby
class UsersController < ApplicationController
  def create
    user = User.create!(user_params)
    UserCreatedHandler.emit({ user_id: user.id, email: user.email })
    redirect_to user
  end
end
```

This is useful when the event source isn't a Servus service.

## Payload Schema Validation

Define JSON schemas to validate event payloads:

```ruby
class UserCreatedHandler < Servus::EventHandler
  handles :user_created

  schema payload: {
    type: 'object',
    required: ['user_id', 'email'],
    properties: {
      user_id: { type: 'integer' },
      email: { type: 'string', format: 'email' }
    }
  }

  invoke SendWelcomeEmail::Service, async: true do |payload|
    { user_id: payload[:user_id], email: payload[:email] }
  end
end
```

When `emit` is called, the payload is validated against the schema before the event is dispatched.

## Handler Validation

Enable strict validation to catch handlers subscribing to non-existent events:

```ruby
# config/initializers/servus.rb
Servus.configure do |config|
  config.strict_event_validation = true  # Default: true
end

# Then manually validate (typically in a rake task or CI)
Servus::EventHandler.validate_all_handlers!
```

This helps catch typos and orphaned handlers during development and CI.

## Best Practices

### Single Event Per Service

Services should emit one event per trigger representing their core concern:

```ruby
# Good - one event, handler coordinates reactions
class CreateUser::Service < Servus::Base
  emits :user_created, on: :success
end

class UserCreatedHandler < Servus::EventHandler
  handles :user_created

  invoke SendWelcomeEmail::Service, async: true
  invoke TrackAnalytics::Service, async: true
  invoke NotifySlack::Service, async: true
end

# Avoid - service doing too much coordination
class CreateUser::Service < Servus::Base
  emits :send_welcome_email, on: :success
  emits :track_user_analytics, on: :success
  emits :notify_slack, on: :success
end
```

### Naming Conventions

- Events: Past tense describing what happened (`user_created`, `payment_processed`)
- Handlers: Event name + "Handler" suffix (`UserCreatedHandler`)

### Handler Location

Handlers live in `app/events/` and are auto-loaded by the Railtie:

```
app/events/
├── user_created_handler.rb
├── payment_processed_handler.rb
└── order_completed_handler.rb
```

## Instrumentation

Events are instrumented via ActiveSupport::Notifications and appear in Rails logs:

```
servus.events.user_created (1.2ms) {:user_id=>123, :email=>"user@example.com"}
```

Subscribe to events programmatically:

```ruby
ActiveSupport::Notifications.subscribe(/^servus\.events\./) do |name, *args|
  event_name = name.sub('servus.events.', '')
  Rails.logger.info "Event emitted: #{event_name}"
end
```