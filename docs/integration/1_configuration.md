# @title Integration / 1. Configuration

# Configuration

Servus works without configuration. Optional settings exist for customizing directories and event validation.

## Directory Configuration

Configure where Servus looks for schemas, services, and event handlers:

```ruby
# config/initializers/servus.rb
Servus.configure do |config|
  # Default: 'app/schemas'
  config.schemas_dir = 'app/schemas'

  # Default: 'app/services'
  config.services_dir = 'app/services'

  # Default: 'app/events'
  config.events_dir = 'app/events'
end
```

These affect legacy file-based schemas and handler auto-loading. Schemas defined via the `schema` DSL method do not use files.

## Schema Cache

Schemas are cached after first load for performance. Clear the cache during development when schemas change:

```ruby
Servus::Support::Validator.clear_cache!
```

In production, schemas are deployed with code - no need to clear cache.

## Log Level

Servus uses `Rails.logger` (or stdout in non-Rails apps). Control logging via Rails configuration:

```ruby
# config/environments/production.rb
config.log_level = :info  # Hides DEBUG argument logs
```

## ActiveJob Configuration

Async execution uses ActiveJob. Configure your adapter:

```ruby
# config/application.rb
config.active_job.queue_adapter = :sidekiq
config.active_job.default_queue_name = :default
```

Servus respects ActiveJob queue configuration - no Servus-specific setup needed.

## Event Bus Configuration

### Strict Event Validation

Enable strict validation to catch handlers subscribing to events that aren't emitted by any service:

```ruby
# config/initializers/servus.rb
Servus.configure do |config|
  # Default: true
  config.strict_event_validation = true
end
```

When enabled, you can validate handlers at boot or in CI:

```ruby
# In a rake task or initializer
Servus::EventHandler.validate_all_handlers!
```

This raises `Servus::Events::OrphanedHandlerError` if any handler subscribes to a non-existent event.

### Handler Auto-Loading

In Rails, handlers in `app/events/` are automatically loaded. The Railtie:
- Clears the event bus on reload in development
- Eager-loads all `*_handler.rb` files from `config.events_dir`

```
app/events/
├── user_created_handler.rb
├── payment_processed_handler.rb
└── order_completed_handler.rb
```

### Event Instrumentation

Events are instrumented via ActiveSupport::Notifications with the prefix `servus.events.`:

```ruby
# Subscribe to all Servus events
ActiveSupport::Notifications.subscribe(/^servus\.events\./) do |name, *args|
  event_name = name.sub('servus.events.', '')
  Rails.logger.info "Event: #{event_name}"
end
```
