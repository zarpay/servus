## Servus Gem

Servus is a gem for creating and managing service objects. It includes:

- A base class for service objects
- Generators for core service objects and specs
- Support for schema validation
- Support for error handling
- Support for logging



## Generators

Service objects can be easily created using the `rails g servus:service namespace/service_name [*params]` command. For sake of consistency, use this command when generating new service objects.

### Generate Service

```bash
$ rails g servus:service namespace/do_something_helpful user
=>    create  app/services/namespace/do_something_helpful/service.rb
      create  spec/services/namespace/do_something_helpful/service_spec.rb
      create  app/schemas/services/namespace/do_something_helpful/result.json
      create  app/schemas/services/namespace/do_something_helpful/arguments.json
```

### Destroy Service

```bash
$ rails d servus:service namespace/do_something_helpful
=>    remove  app/services/namespace/do_something_helpful/service.rb
      remove  spec/services/namespace/do_something_helpful/service_spec.rb
      remove  app/schemas/services/namespace/do_something_helpful/result.json
      remove  app/schemas/services/namespace/do_something_helpful/arguments.json
```

## Arguments

Service objects should use keyword arguments rather than positional arguments for improved clarity and more meaningful error messages.

```ruby
# Good ✅
class Services::ProcessPayment::Service < Servus::Base
  def initialize(user:, amount:, payment_method:)
    @user = user
    @amount = amount
    @payment_method = payment_method
  end
end

# Bad ❌
class Services::ProcessPayment::Service < Servus::Base
  def initialize(user, amount, payment_method)
    @user = user
    @amount = amount
    @payment_method = payment_method
  end
end
```

## Directory Structure

Each service belongs in its own namespace with this structure:

- `app/services/service_name/service.rb` - Main class/entry point
- `app/services/service_name/support/` - Service-specific supporting classes

Supporting classes should never be used outside their parent service.

```
app/services/
├── process_payment/
│   ├── service.rb
│   └── support/
│       ├── payment_validator.rb
│       └── receipt_generator.rb
├── generate_report/
│   ├── service.rb
│   └── support/
│       ├── report_formatter.rb
│       └── data_collector.rb
```

## **Methods**

Every service object must implement:

- An `initialize` method that sets instance variables
- A parameter-less `call` instance method that executes the service logic

```ruby
class Services::GenerateReport::Service < Servus::Base
  def initialize(user:, report_type:, date_range:)
    @user = user
    @report_type = report_type
    @date_range = date_range
  end

  def call
    data = collect_data
    if data.empty?
      return failure("No data available for the selected date range")
    end

    formatted_report = format_report(data)
    success(formatted_report)
  end

  private

  def collect_data
		# Implementation details...
	end

  def format_report(data)
		# Implementation details...
	end
end

```

Here’s a section you can add to your README for the new `.call_async` feature, matching the style of your existing `## Inheritance` section:

---

## **Asynchronous Execution**

You can asynchronously execute any service class that inherits from `Servus::Base` using `.call_async`. This uses `ActiveJob` under the hood and supports standard job options (`wait`, `queue`, `priority`, etc.). Only available in environments where `ActiveJob` is loaded (e.g., Rails apps)

```ruby
# Good ✅
Services::NotifyUser::Service.call_async(
  user_id: current_user.id,
  wait: 5.minutes,
  queue: :low_priority,
  job_options: { tags: ['notifications'] }
)

# Bad ❌
Services::NotifyUser::Support::MessageBuilder.call_async(
  # Invalid: support classes don't inherit from Servus::Base
)
```

## **Inheritance**

- Every main service class (`service.rb`) must inherit from `Servus::Base`
- Supporting classes should NOT inherit from `Servus::Base`

```ruby
# Good ✅
class Services::NotifyUser::Service < Servus::Base
	# Service implementation
end

class Services::NotifyUser::Support::MessageBuilder
	# Support class implementation (does NOT inherit from BaseService)
end

# Bad ❌
class Services::NotifyUser::Support::MessageBuilder < Servus::Base
	# Incorrect: support classes should not inherit from Base class
end
```

## **Call Chain**

Always use the class method `call` instead of manual instantiation. The `call` method:

1. Initializes an instance of the service using provided keyword arguments
2. Calls the instance-level `call` method
3. Handles schema validation of inputs and outputs
4. Handles logging of inputs and results

```ruby
# Good ✅
result = Services::ProcessPayment::Service.call(
  amount: 50,
  user_id: 123,
  payment_method: "credit_card"
)

# Bad ❌ - bypasses logging and other class-level functionality
service = Services::ProcessPayment::Service.new(
  amount: 50,
  user_id: 123,
  payment_method: "credit_card"
)
result = service.call

```

When services call other services, always use the class-level `call` method:

```ruby
def process_order
# Good ✅
  payment_result = Services::ProcessPayment::Service.call(
    amount: @order.total,
    payment_method: @payment_details
  )

# Bad ❌
  payment_service = Services::ProcessPayment::Service.new(
    amount: @order.total,
    payment_method: @payment_details
  )
  payment_result = payment_service.call
end

```

## **Responses**

The `Servus::Base` provides standardized response methods:

- `success(data)` - Returns success with data as a single argument
- `failure(message, **options)` - Logs error and returns failure response
- `error!(message)` - Logs error and raises exception

```ruby
def call
	# Return failure with message
	return failure("Order is not in a pending state") unless @order.pending?

    # Do something important

	# Process and return success with single data object
    success({
        order_id: @order.id,
        status: "processed",
        timestamp: Time.now
    })
end
```

All responses are `Servus::Support::Response` objects with a `success?` boolean attribute and either `data` (for success) or `error` (for error) attributes.

### Service Error Returns and Handling

By default, the `failure(...)` method creates an instance of `ServiceError` and adds it to the response type's `error` attribute. Standard and custom error types should inherit from the `ServiceError` class and optionally implement a custom `api_error` method. This enables developers to choose between using an API-specific error or generic error message in the calling context.

```ruby
# Called from within a Service Object
class SomeServiceObject::Service < Servus::Base
	def call
		# Return default ServiceError with custom message
		failure("That didn't work for some reason")
		#=> Response(false, nil, ApplicationService::Support::Errors::ServiceError("That didn't work for some reason"))
		#
		# OR
		#
		# Specify ServiceError type with custom message
		failure("Custom message", type: Servus::Support::Errors::NotFoundError)
		#=> Response(false, nil, ApplicationService::Support::Errors::NotFoundError("Custom message"))
		#
		# OR
		#
		# Specify ServiceError type with default message
		failure(type: Servus::Support::Errors::NotFoundError)
		#=> Response(false, nil, ApplicationService::Support::Errors::NotFoundError("Record not found"))
		#
		# OR
		#
		# Accept all defaults
		failure
		#=> Response(false, nil, ApplicationService::Support::Errors::ServiceError("An error occurred"))
	end
end

# Error handling in parent context
class SomeController < AppController
	def controller_action
	  result = SomeServiceObject::Service.call(arg: 1)

	  return if result.success?

	  # If you just want the error message
	  bad_request(result.error.message)

	  # If you want the API error
	  service_object_error(result.error.api_error)
	end
end
```

### `rescue_from` for service errors

Services can configure default error handling using the `rescue_from` method.

```ruby
class SomeServiceObject::Service < Servus::Base
  class SomethingBroke < StandardError; end
  class SomethingGlitched < StandardError; end

  # Rescue from standard errors and use custom error
  rescue_from
    SomethingBroke,
    SomethingGlitched,
    use: Servus::Support::Errors::ServiceUnavailableError # this is optional

  def call
    do_something
  end

  private

  def do_something
    make_and_api_call
    rescue Net::HTTPError => e
      raise SomethingGlitched, "Whoaaaa, something went wrong! #{e.message}"
    end
  end
end
```

```sh
result = SomeServiceObject::Service.call
# Failure response
result.error.class
=> Servus::Support::Errors::ServiceUnavailableError
result.error.message
=> "[SomeServiceObject::Service::SomethingGlitched]: Whoaaaa, something went wrong! Net::HTTPError (503)"
result.error.api_error
=> { code: :service_unavailable, message: "[SomeServiceObject::Service::SomethingGlitched]: Whoaaaa, something went wrong! Net::HTTPError (503)" }
```

The `rescue_from` method will rescue from the specified errors and use the specified error type to create a failure response object with
the custom error. It helps eliminate the need to manually rescue many errors and create failure responses within the call method of
a service object.

## Controller Helpers

Service objects can be called from controllers using the `run_service` and `render_service_object_error` helpers.

### run_service

`run_service` calls the service object with the provided parameters and set's an instance variable `@result` to the
result of the service object if the result is successful. If the result is not successful, it will pass the result
to error to the `render_service_object_error` helper. This allows for easy error handling in the controller for
repetetive usecases.

```ruby
class SomeController < AppController
  # Before
  def controller_action
    result = Services::SomeServiceObject::Service.call(my_params)
    return if result.success?
    render_service_object_error(result.error.api_error)
  end

  # After
  def controller_action_refactored
    run_service Services::SomeServiceObject::Service, my_params
  end
end
```

### render_service_object_error

`render_service_object_error` renders the error of a service object. It expects a hash with a `message` key and a `code` key from
the api_error method of the service error. This is all setup by default for a JSON API response, thought the method can be
overridden if needed to handle different usecases.

```ruby
# Behind the scenes, render_service_object_error calls the following:
#
#  error = result.error.api_error
#  => { message: "Error message", code: 400 }
#
#  render json: { message: error[:message], code: error[:code] }, status: error[:code]

class SomeController < AppController
  def controller_action
    result = Services::SomeServiceObject::Service.call(my_params)
    return if result.success?

    render_service_object_error(result.error.api_error)
  end
end
```

## **Schema Validation**

Service objects support two methods for schema validation: JSON Schema files and inline schema declarations.

### 1. File-based Schema Validation

Every service can have corresponding schema files in the centralized schema directory:

- `app/schemas/services/service_name/arguments.json` - Validates input arguments
- `app/schemas/services/service_name/result.json` - Validates success response data

Example `arguments.json`:

```json
{
  "type": "object",
  "required": ["user_id", "amount", "payment_method"],
  "properties": {
    "user_id": { "type": "integer" },
    "amount": {
      "type": "integer",
      "minimum": 1
    },
    "payment_method": {
      "type": "string",
      "enum": ["credit_card", "paypal", "bank_transfer"]
    },
    "currency": {
      "type": "string",
      "default": "USD"
    }
  },
  "additionalProperties": false
}

```

Example `result.json`:

```json
{
  "type": "object",
  "required": ["transaction_id", "status"],
  "properties": {
    "transaction_id": { "type": "string" },
    "status": {
      "type": "string",
      "enum": ["approved", "pending", "declined"]
    },
    "receipt_url": { "type": "string" }
  }
}

```

### 2. Inline Schema Validation

Alternatively, schemas can be declared directly within the service class using `ARGUMENTS_SCHEMA` and `RESULT_SCHEMA` constants.

```ruby
class Services::ProcessPayment::Service < Servus::Base
  ARGUMENTS_SCHEMA = {
	  type: "object",
	  required: ["user_id", "amount", "payment_method"],
	  properties: {
	    user_id: { type: "integer" },
	    amount: {
	      type: "integer",
	      minimum: 1
	    },
	    payment_method: {
	      type: "string",
	      enum: ["credit_card", "paypal", "bank_transfer"]
	    },
	    currency: {
	      type: "string",
	      default: "USD"
	    }
	  },
	  additionalProperties: false
	}

  RESULT_SCHEMA = {
	  type: "object",
	  required: ["transaction_id", "status"],
	  properties: {
	    transaction_id: { type: "string" },
	    status: {
	      type: "string",
	      enum: ["approved", "pending", "declined"]
	    },
	    receipt_url: { type: "string" }
	  }
	}
end
```

---

These schemas use JSON Schema format to enforce type safety and input/output contracts. For detailed information on authoring JSON Schema files, refer to the official specification at: https://json-schema.org/specification.html

### Schema Resolution

The validation system follows this precedence:

1. Checks for inline schema constants (`ARGUMENTS_SCHEMA` or `RESULT_SCHEMA`)
2. Falls back to JSON files if no inline schema is found
3. Returns nil if neither exists

### Schema Caching

Both file-based and inline schemas are automatically cached:

- First validation request loads and caches the schema
- Subsequent validations use the cached version
- Cache can be cleared using `SchemaValidation.clear_cache!`
