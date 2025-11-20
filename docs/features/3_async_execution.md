# @title Features / 3. Async Execution

# Async Execution

Servus provides asynchronous execution via ActiveJob. Services run identically whether called sync or async - they're unaware of execution context.

## Usage

Call `.call_async(**args)` instead of `.call(**args)` to execute in the background. The service is enqueued immediately and executed by a worker.

```ruby
# Synchronous
result = ProcessReport::Service.call(user_id: user.id, report_type: :monthly)
result.data[:report] # Available immediately

# Asynchronous
ProcessReport::Service.call_async(user_id: user.id, report_type: :monthly)
# Returns true if enqueued successfully
# Result not available (service hasn't run yet)
```

Services must accept JSON-serializable arguments for async execution (primitives, hashes, arrays, ActiveRecord objects via GlobalID). Complex objects like Procs won't work.

## Queue and Scheduling Options

Pass ActiveJob options to control execution:

```ruby
ProcessReport::Service.call_async(
  user_id: user.id,
  queue: :critical,      # Specify queue
  priority: 10,          # Higher priority
  wait: 5.minutes        # Delay execution
)
```

## Result Handling

Async services can't return results to callers (the service hasn't executed yet). If you need results, implement persistence in the service:

```ruby
class GenerateReport::Service < Servus::Base
  def call
    report_data = generate_report

    # Persist result
    Report.create!(
      user_id: @user_id,
      data: report_data,
      status: 'completed'
    )

    # Optionally notify user
    UserMailer.report_ready(@user_id).deliver_now

    success(data: report_data)
  end
end

# Controller creates placeholder, service updates it
report = Report.create!(user_id: user.id, status: 'pending')
GenerateReport::Service.call_async(user_id: user.id, report_id: report.id)
```

## Error Handling

Failures (business logic) don't trigger retries - the job completes successfully but returns a failure Response.

Exceptions (system errors) trigger ActiveJob retry logic. Use `rescue_from` to convert transient errors into exceptions:

```ruby
class Service < Servus::Base
  rescue_from Net::HTTPError, Timeout::Error use: ServiceUnavailableError
end
```

## When to Use Async

**Good candidates**: Email sending, report generation, data imports, long-running API calls, cleanup tasks

**Poor candidates**: Operations requiring immediate feedback, fast operations (<100ms), critical path operations where user waits for result
