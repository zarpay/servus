# Logging

Servus automatically logs all service executions with timing information. No instrumentation code needed in services.

## What Gets Logged

**Service calls** (DEBUG): Service class name and arguments
```
[Servus] Users::Create::Service called with {:email=>"user@example.com", :name=>"John"}
```

**Successful completions** (INFO): Service class name and duration
```
[Servus] Users::Create::Service completed successfully in 0.0243s
```

**Failures** (WARN): Service class name, error type, message, and duration
```
[Servus] Users::Create::Service failed with NotFoundError: User not found (0.0125s)
```

**Exceptions** (ERROR): Service class name, exception type, message, and duration
```
[Servus] Users::Create::Service raised ArgumentError: Missing required field (0.0089s)
```

## Log Levels

Servus uses Rails.logger and respects application log level configuration:

- **DEBUG**: Shows arguments (use in development, hide in production to avoid logging sensitive data)
- **INFO**: Shows completions (normal operations)
- **WARN**: Shows business failures
- **ERROR**: Shows system exceptions

Set production log level to INFO to hide argument logging:

```ruby
# config/environments/production.rb
config.log_level = :info
```

## Sensitive Data

Arguments are logged at DEBUG level. In production, either:
1. Set log level to INFO (recommended)
2. Use Rails parameter filtering: `config.filter_parameters += [:password, :ssn, :credit_card]`
3. Pass IDs instead of full objects: `Service.call(user_id: 1)` not `Service.call(user: user_object)`

## Integration with Logging Tools

The `[Servus]` prefix makes service logs easy to grep and filter:

```bash
# Find all service calls
grep "\[Servus\]" production.log

# Find slow services
grep "completed" production.log | grep "Servus" | awk '{print $NF}' | sort -n
```

Servus logs work with structured logging tools (Lograge, Datadog, Splunk) without modification.
