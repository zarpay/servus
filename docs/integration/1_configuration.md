# @title Integration / 1. Configuration

# Configuration

Servus works without configuration. One optional setting exists for schema file location.

## Schema Root

By default, Servus looks for schema JSON files in `Rails.root/app/schemas/services` (or `./app/schemas/services` in non-Rails apps).

Change the location if needed:

```ruby
# config/initializers/servus.rb
Servus.configure do |config|
  config.schema_root = Rails.root.join('config/schemas')
end
```

This affects legacy file-based schemas only - schemas defined via the `schema` DSL method do not use files.

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
