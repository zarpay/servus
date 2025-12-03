# Servus Event Bus Specification

## 1. Overview & Philosophy

This document specifies the design and API for a native event bus within the Servus gem. The core philosophy is **clean separation of concerns**, ensuring that services remain focused on business logic, while a dedicated, lightweight layer handles the routing of events to service invocations.

This approach is defined by three distinct layers:

1. **The Emitter (****`Servus::Base`****)**: A service that performs a business function and declares the events it emits upon completion.

1. **The Mapper (****`Servus::EventHandler`****)**: A new, lightweight class whose sole responsibility is to subscribe to a single event and declaratively map it to one or more service invocations.

1. **The Consumer (****`Servus::Base`****)**: A service that is invoked by the event handler and performs a subsequent business function, without needing any awareness of the eventing system.

This design avoids overloading service classes with subscription logic and eliminates the need for auto-generated code, resulting in a system that is explicit, discoverable, and highly maintainable.

---

## 2. Core Components

### 2.1. The Emitter: `Servus::Base`

Services that emit events will use a class-level `emits` method to declare them.

#### **API: ****`emits(event_name, on:, with: nil)`**

- **`event_name`**** (Symbol)**: The unique name of the event (e.g., `:referral_created`).

- **`on`**** (Symbol)**: The trigger for automatic emission. Must be `:success` or `:failure`.

- **`with`**** (Symbol, Optional)**: The name of an instance method on the service that will build the event payload. This method receives the service's `Servus::Support::Response` object as its only argument.

If the `with:` option is omitted, the payload will be `result.data` for a success event or `{ error: result.error }` for a failure event.

#### **Example: Service Declaration**

```ruby
# app/services/referrals/create_referral/service.rb
class Referrals::CreateReferral::Service < Servus::Base
  # On success, emit :referral_created, building the payload with the
  # :referral_payload instance method.
  emits :referral_created, on: :success, with: :referral_payload

  # On failure, emit :referral_failed with a default error payload.
  emits :referral_failed, on: :failure

  # On error, emit :referral_error with a default error payload
  emits :referral_error, on: :error

  def initialize(referee_id:)
    @referee_id = referee_id
  end

  def call
    # ... business logic ...

    # The :referral_created event is automatically emitted here upon success.
    success({ referral: @referral, referee: @referee, referrer: @referrer })
  end

  private

  # This method is called by the event system to build the payload.
  def referral_payload(result)
    {
      referral_id: result.data[:referral].id,
      referee_id: result.data[:referee].id,
      referrer_id: result.data[:referrer].id,
      created_at: Time.current
    }
  end
end
```

### 2.2. The Mapper: `Servus::EventHandler`

This is a new, lightweight class that lives in the `app/events` directory. Each handler subscribes to a single event and maps it to one or more service invocations.

#### **API: ****`handles(event_name)`**

- **`event_name`**** (Symbol)**: The unique name of the event this class handles.

#### **API: ****`invoke(service_class, options = {}, &block)`**

- **`service_class`**** (Class)**: The `Servus::Base` subclass to be invoked.

- **`options`**** (Hash, Optional)**: A hash of options for the invocation.
  - `:async` (Boolean): If `true`, invokes the service using `.call_async`. Defaults to `false`.
  - `:queue` (Symbol): The queue name to use for async jobs.
  - `:if` (Proc): A lambda that receives the payload and must return `true` for the invocation to proceed.
  - `:unless` (Proc): A lambda that receives the payload and must return `false` for the invocation to proceed.

- **`&block`**** (Block)**: A block that receives the event payload and **must** return a hash of keyword arguments for the target service's `initialize` method.

#### **Example: Event Handler**

```ruby
# app/events/referral_created_handler.rb
class ReferralCreatedHandler < Servus::EventHandler
  # Subscribe to the :referral_created event.
  handles :referral_created

  # Define an invocation for the Rewards::GrantReferralRewards::Service.
  invoke Rewards::GrantReferralRewards::Service, async: true do |payload|
    # Map the event payload to the service's required arguments.
    { user_id: payload[:referrer_id] }
  end

  # Define another invocation for the Referrals::ActivityNotifier::Service.
  invoke Referrals::ActivityNotifier::Service, async: true, queue: :notifications do |payload|
    { referral_id: payload[:referral_id] }
  end
end
```

### 2.3. Automatic Registration

All classes inheriting from `Servus::EventHandler` within the `app/events` directory will be automatically discovered and registered by the gem at boot time. No manual configuration is required.

---

## 3. Directory Structure

The introduction of `EventHandler` classes establishes a new conventional directory:

```
app/
├── events/                          # New directory for event handlers
│   ├── referral_created_handler.rb
│   └── user_graduated_handler.rb
├── services/
│   ├── referrals/
│   │   └── create_referral/
│   │       └── service.rb          # Emitter
│   └── rewards/
│       └── grant_referral_rewards/
│           └── service.rb          # Consumer
└── ...
```

---

## 4. Generators

A Rails generator will be provided to facilitate the creation of `EventHandler` classes.

#### **Command**

```bash
$ rails g servus:event_handler referral_created
```

#### **Output**

This command will generate two files:

1. `app/events/referral_created_handler.rb`

1. `spec/events/referral_created_handler_spec.rb`

#### **Generated Handler Template**

```ruby
# app/events/referral_created_handler.rb
class ReferralCreatedHandler < Servus::EventHandler
  handles :referral_created

  # TODO: Add service invocations using the `invoke` DSL.
  #
  # Example:
  # invoke SomeService, async: true do |payload|
  #   { argument_name: payload[:some_key] }
  # end
end
```

---

## 5. Testing Strategy

The separation of concerns enables focused and decoupled testing.

### 5.1. Testing Event Emission

When testing a service, you should only assert that the correct event was emitted with the expected payload. A test helper will be provided for this.

```ruby
# spec/services/referrals/create_referral/service_spec.rb
RSpec.describe Referrals::CreateReferral::Service do
  include Servus::Events::TestHelpers

  it 'emits a :referral_created event on success' do
    # Assert that the block will cause the specified event to be emitted.
    expect_event(:referral_created)
      .with_payload(hash_including(:referral_id, :referee_id, :referrer_id))
      .when { described_class.call(referee_id: referee.id) }
  end
end
```

### 5.2. Testing an Event Handler

When testing a handler, you should provide a sample payload and assert that the correct services are invoked with the correctly mapped arguments.

```ruby
# spec/events/referral_created_handler_spec.rb
RSpec.describe ReferralCreatedHandler do
  let(:payload) do
    {
      referral_id: 'referral-123',
      referrer_id: 'user-456',
      referee_id: 'user-789',
      created_at: Time.current
    }
  end

  it 'invokes the GrantReferralRewards service with the correct user ID' do
    expect(Rewards::GrantReferralRewards::Service)
      .to receive(:call_async)
      .with(user_id: 'user-456')

    # Trigger the handler with the test payload.
    described_class.handle(payload)
  end

  it 'invokes the ActivityNotifier service with the correct referral ID' do
    expect(Referrals::ActivityNotifier::Service)
      .to receive(:call_async)
      .with(referral_id: 'referral-123', queue: :notifications)

    described_class.handle(payload)
  end
end
```

---

## 6. Implementation Plan

This section provides a detailed, phase-by-phase breakdown of tasks required to implement the event bus feature. Each phase builds upon the previous one, and tasks are organized by logical implementation order.

### Phase 1: Core Event Infrastructure

**Goal**: Establish the foundational event emission capability in `Servus::Base`.

- [ ] **Create Event Bus/Registry** (`lib/servus/events/bus.rb`)
  - Create `Servus::Events::Bus` singleton class
  - Implement event registration: `Bus.register_handler(event_name, handler_class)`
  - Implement event emission: `Bus.emit(event_name, payload)`
  - Store handlers in a thread-safe Hash: `@handlers = Concurrent::Hash.new { |h, k| h[k] = [] }`
  - Add method to dispatch event to all registered handlers
  - **Files**: `lib/servus/events/bus.rb`, `spec/servus/events/bus_spec.rb`

- [ ] **Add `emits` DSL to Servus::Base** (`lib/servus/base.rb`)
  - Create class-level `emits(event_name, on:, with: nil)` method
  - Store event declarations in class instance variable: `@event_emissions ||= []`
  - Validate `on:` parameter is one of: `:success`, `:failure`, `:error`
  - Store event config as: `{ event_name:, trigger:, payload_builder: }`
  - Add accessor method: `def self.event_emissions; @event_emissions || []; end`
  - **Files**: `lib/servus/base.rb:30-50`

- [ ] **Implement Automatic Event Emission** (`lib/servus/base.rb`)
  - In `#call` method, after executing user's `#call` (around line 120):
    - After success: trigger events where `on: :success`
    - After failure: trigger events where `on: :failure`
    - In rescue blocks: trigger events where `on: :error`
  - Create private method `#emit_events_for(trigger_type, result)`
  - **Files**: `lib/servus/base.rb:120-140`

- [ ] **Implement Payload Builder Logic** (`lib/servus/base.rb`)
  - Create private method `#build_event_payload(event_config, result)`
  - If `with:` option present: call instance method with `result` as argument
  - If `with:` absent and success: return `result.data`
  - If `with:` absent and failure/error: return `{ error: result.error }`
  - Handle case where custom payload builder returns nil (log warning, use default)
  - **Files**: `lib/servus/base.rb:250-270`

- [ ] **Write Comprehensive Specs**
  - Test `emits` DSL declaration and storage
  - Test automatic emission on success/failure/error
  - Test custom payload builders via `with:` option
  - Test default payloads when `with:` omitted
  - Test multiple event declarations on same service
  - Test events inherited by subclasses
  - **Files**: `spec/servus/base_spec.rb:450-600` (new section)

### Phase 2: EventHandler Base Class

**Goal**: Create the `Servus::EventHandler` class with the `handles` and `invoke` DSL.

- [ ] **Create EventHandler Base Class** (`lib/servus/event_handler.rb`)
  - Create `Servus::EventHandler` class
  - Add class instance variable: `@event_name` for event subscription
  - Add class instance variable: `@invocations = []` for service mappings
  - Add reader: `def self.event_name; @event_name; end`
  - Add reader: `def self.invocations; @invocations || []; end`
  - **Files**: `lib/servus/event_handler.rb`, `spec/servus/event_handler_spec.rb`

- [ ] **Implement `handles` DSL Method** (`lib/servus/event_handler.rb`)
  - Create class method: `def self.handles(event_name)`
  - Store event name: `@event_name = event_name`
  - Automatically register with Bus: `Servus::Events::Bus.register_handler(event_name, self)`
  - Raise error if `handles` called multiple times in same class
  - **Files**: `lib/servus/event_handler.rb:20-30`

- [ ] **Implement `invoke` DSL Method** (`lib/servus/event_handler.rb`)
  - Create class method: `def self.invoke(service_class, options = {}, &block)`
  - Validate `service_class` is a subclass of `Servus::Base`
  - Validate `options` keys are valid: `:async`, `:queue`, `:if`, `:unless`
  - Require block to be present (raise error if missing)
  - Store invocation config: `@invocations << { service_class:, options:, mapper: block }`
  - **Files**: `lib/servus/event_handler.rb:40-60`

- [ ] **Implement Event Handling Dispatcher** (`lib/servus/event_handler.rb`)
  - Create class method: `def self.handle(payload)`
  - Iterate over `@invocations`
  - For each invocation:
    - Check `:if` condition (skip if returns false)
    - Check `:unless` condition (skip if returns true)
    - Call mapper block with payload to get service kwargs
    - Invoke service: `service_class.call(**kwargs)` or `.call_async(**kwargs.merge(queue: options[:queue]))`
  - Return array of results from all invocations
  - **Files**: `lib/servus/event_handler.rb:70-95`

- [ ] **Handle Async Options** (`lib/servus/event_handler.rb`)
  - When `async: true`, use `service_class.call_async(**kwargs)`
  - Pass `:queue` option to `call_async` if present
  - Ensure async calls work with existing `Servus::Extensions::Async` module
  - **Files**: `lib/servus/event_handler.rb:85-90`

- [ ] **Implement Conditional Logic** (`lib/servus/event_handler.rb`)
  - Create private method: `def self.should_invoke?(payload, options)`
  - Check `:if` proc: `return false if options[:if] && !options[:if].call(payload)`
  - Check `:unless` proc: `return false if options[:unless] && options[:unless].call(payload)`
  - Return true if all conditions pass
  - **Files**: `lib/servus/event_handler.rb:100-110`

- [ ] **Write Comprehensive Specs**
  - Test `handles` DSL declaration and registration
  - Test `invoke` DSL with various options
  - Test `.handle(payload)` dispatches to services correctly
  - Test conditional execution (`:if`, `:unless`)
  - Test sync vs async invocation
  - Test queue routing for async jobs
  - Test multiple invocations in single handler
  - Test payload mapping via block
  - **Files**: `spec/servus/event_handler_spec.rb`

### Phase 3: Automatic Handler Discovery

**Goal**: Auto-discover and register all EventHandler classes in `app/events/` at Rails boot.

- [ ] **Create Railtie for Initialization** (`lib/servus/railtie.rb`)
  - Update existing railtie or create if doesn't exist
  - Add initializer: `initializer 'servus.discover_event_handlers', after: :load_config_initializers`
  - In initializer, call `Servus::Events::Loader.discover_handlers`
  - **Files**: `lib/servus/railtie.rb:20-30`

- [ ] **Create Handler Discovery Loader** (`lib/servus/events/loader.rb`)
  - Create `Servus::Events::Loader` module
  - Method: `def self.discover_handlers`
  - Scan `app/events/**/*_handler.rb` using `Dir.glob`
  - Require each file: `require_dependency(file_path)`
  - Return count of discovered handlers for logging
  - **Files**: `lib/servus/events/loader.rb`, `spec/servus/events/loader_spec.rb`

- [ ] **Add Handler Conflict Detection** (`lib/servus/events/bus.rb`)
  - In `Bus.register_handler`, detect if event already has handler
  - Raise `Servus::Events::DuplicateHandlerError` if duplicate detected
  - Include both handler class names in error message
  - Add config option to allow multiple handlers (default: false)
  - **Files**: `lib/servus/events/bus.rb:25-35`

- [ ] **Create Custom Errors** (`lib/servus/events/errors.rb`)
  - Create `Servus::Events::DuplicateHandlerError < StandardError`
  - Create `Servus::Events::UnregisteredEventError < StandardError`
  - **Files**: `lib/servus/events/errors.rb`

- [ ] **Add Development Mode Reloading** (`lib/servus/railtie.rb`)
  - Clear handler registry on code reload: `to_prepare` hook
  - Call `Servus::Events::Bus.clear` before re-discovering
  - Ensure handlers re-register properly in development
  - **Files**: `lib/servus/railtie.rb:35-40`

- [ ] **Write Comprehensive Specs**
  - Test handler discovery in dummy Rails app
  - Test duplicate handler detection raises error
  - Test handler reloading in development mode
  - Test nested handler files are discovered
  - Test handlers are properly registered with Bus
  - **Files**: `spec/servus/events/loader_spec.rb`, `spec/integration/handler_discovery_spec.rb`

### Phase 4: Test Helpers

**Goal**: Provide intuitive test helpers for asserting event emissions and testing handlers.

- [ ] **Create Test Helpers Module** (`lib/servus/events/test_helpers.rb`)
  - Create `Servus::Events::TestHelpers` module
  - Add RSpec-specific helpers
  - Include event capture/inspection utilities
  - **Files**: `lib/servus/events/test_helpers.rb`, `spec/servus/events/test_helpers_spec.rb`

- [ ] **Implement `expect_event` Matcher** (`lib/servus/events/test_helpers.rb`)
  - Create chainable matcher: `expect_event(event_name)`
  - Implement `.with_payload(expected_payload)` chain
  - Implement `.when { block }` chain that executes code
  - Capture events emitted during block execution
  - Assert event was emitted with matching payload
  - Use RSpec's `hash_including` for partial payload matching
  - **Files**: `lib/servus/events/test_helpers.rb:10-60`

- [ ] **Create Event Capture Mechanism** (`lib/servus/events/test_helpers.rb`)
  - Create thread-local event store: `@captured_events = []`
  - Hook into `Bus.emit` to capture events during tests
  - Method: `def capture_events(&block)` that returns array of emitted events
  - Auto-clear captured events between test runs
  - **Files**: `lib/servus/events/test_helpers.rb:70-90`

- [ ] **Add Handler Testing Utilities** (`lib/servus/events/test_helpers.rb`)
  - Helper method: `trigger_event(event_name, payload)` for directly testing handlers
  - Method to assert handler invoked specific service: `expect_handler_to_invoke(service_class)`
  - Method to build sample payloads: `sample_payload_for(event_name)`
  - **Files**: `lib/servus/events/test_helpers.rb:100-130`

- [ ] **Create RSpec Configuration** (`lib/servus/events/test_helpers.rb`)
  - Add RSpec config to auto-include TestHelpers in event specs
  - Add config to auto-clear event registry between tests
  - Add matcher aliases for readability
  - **Files**: `lib/servus/events/test_helpers.rb:140-160`

- [ ] **Write Comprehensive Specs and Examples**
  - Test `expect_event` matcher with various payload matchers
  - Test `.when` block execution and event capture
  - Test negative cases (event not emitted, wrong payload)
  - Test handler testing utilities
  - Create example specs showing usage patterns
  - **Files**: `spec/servus/events/test_helpers_spec.rb`, `spec/examples/event_testing_spec.rb`

### Phase 5: Generator

**Goal**: Provide Rails generator for quickly scaffolding new EventHandler classes and specs.

- [ ] **Create Generator Class** (`lib/generators/servus/event_handler/event_handler_generator.rb`)
  - Inherit from `Rails::Generators::NamedBase`
  - Set source root: `source_root File.expand_path('templates', __dir__)`
  - Define generator description and usage
  - **Files**: `lib/generators/servus/event_handler/event_handler_generator.rb`

- [ ] **Implement File Generation Logic** (`lib/generators/servus/event_handler/event_handler_generator.rb`)
  - Method: `def create_handler_file`
  - Generate file at: `app/events/#{file_name}_handler.rb`
  - Use ERB template with proper class name and event name
  - Method: `def create_spec_file`
  - Generate file at: `spec/events/#{file_name}_handler_spec.rb`
  - **Files**: `lib/generators/servus/event_handler/event_handler_generator.rb:15-30`

- [ ] **Create Handler Template** (`lib/generators/servus/event_handler/templates/handler.rb.tt`)
  - ERB template with `<%= class_name %>Handler < Servus::EventHandler`
  - Include `handles :<%= event_name %>`
  - Include TODO comment with example invoke usage
  - **Files**: `lib/generators/servus/event_handler/templates/handler.rb.tt`

- [ ] **Create Spec Template** (`lib/generators/servus/event_handler/templates/handler_spec.rb.tt`)
  - ERB template for RSpec test file
  - Include sample payload `let` block
  - Include example test for service invocation
  - Include pending test for additional invocations
  - **Files**: `lib/generators/servus/event_handler/templates/handler_spec.rb.tt`

- [ ] **Add Naming Conventions** (`lib/generators/servus/event_handler/event_handler_generator.rb`)
  - Convert snake_case event names to proper class names
  - Example: `referral_created` → `ReferralCreatedHandler`
  - Handle multi-word event names correctly
  - Add validation for event name format (only alphanumeric and underscores)
  - **Files**: `lib/generators/servus/event_handler/event_handler_generator.rb:40-55`

- [ ] **Write Generator Specs** (`spec/generators/servus/event_handler_generator_spec.rb`)
  - Test generator creates handler file in correct location
  - Test generator creates spec file in correct location
  - Test generated files have correct content/structure
  - Test naming conventions work correctly
  - Test generator with various event name formats
  - Use `Rails::Generators::TestCase` for generator testing
  - **Files**: `spec/generators/servus/event_handler_generator_spec.rb`

### Phase 6: Documentation & Polish

**Goal**: Document the event bus feature and prepare for release.

- [ ] **Move Spec to Feature Docs** (`docs/features/5_event_bus.md`)
  - Copy content from `docs/current_focus.md` to `docs/features/5_event_bus.md`
  - Remove "Implementation Plan" section (internal only)
  - Polish language to be present tense ("The event bus provides...")
  - Add introduction paragraph linking to related features (async execution)
  - **Files**: `docs/features/5_event_bus.md`

- [ ] **Update Current Focus** (`docs/current_focus.md`)
  - Clear or archive current content
  - Add new focus area (could be generator updates from IDEAS.md)
  - Or mark as "Event bus implementation complete, awaiting next focus"
  - **Files**: `docs/current_focus.md`

- [ ] **Update README** (`READme.md`)
  - Add "Event Bus" section under features list
  - Add quick example showing emitter → handler → consumer flow
  - Add link to full documentation: `docs/features/5_event_bus.md`
  - Keep example concise (10-15 lines)
  - **Files**: `READme.md:30-60`

- [ ] **Add YARD Documentation** (various files)
  - Document `Servus::Base.emits` with @param and @example tags
  - Document `Servus::EventHandler` class and DSL methods
  - Document `Servus::Events::Bus` public methods
  - Document test helpers module and matchers
  - Generate updated YARD docs: `bundle exec yard doc`
  - **Files**: `lib/servus/base.rb`, `lib/servus/event_handler.rb`, etc.

- [ ] **Update CHANGELOG** (`CHANGELOG.md`)
  - Add new section: `## [0.2.0] - Unreleased`
  - List new features:
    - Event bus with `emits` DSL for services
    - `Servus::EventHandler` for mapping events to service invocations
    - Automatic handler discovery in `app/events/`
    - Test helpers with `expect_event` matcher
    - Generator: `rails g servus:event_handler`
  - Note any breaking changes (hopefully none)
  - **Files**: `CHANGELOG.md:1-20`

- [ ] **Create Migration Guide** (`docs/guides/3_adding_events.md`)
  - Guide for adding events to existing services
  - Walkthrough: identify business events → add `emits` → create handler → test
  - Best practices: when to use events vs direct service calls
  - Common patterns: notification events, audit events, workflow triggers
  - Troubleshooting: handler not found, payload mapping issues
  - **Files**: `docs/guides/3_adding_events.md`

- [ ] **Update Version Number** (`lib/servus/version.rb`)
  - Bump version to `0.2.0` (minor version for new feature)
  - Update version in `servus.gemspec` if needed
  - **Files**: `lib/servus/version.rb:3`

---

### Implementation Notes

**Testing Strategy**:
- Write specs FIRST for each component (TDD approach)
- Use dummy Rails app in `spec/dummy` for integration tests
- Test thread safety for Bus registry (use concurrent gem)

**Performance Considerations**:
- Event emission should add < 1ms to service execution
- Handler lookup should be O(1) using hash-based registry
- Consider async-by-default for most event handlers to avoid blocking

**Backward Compatibility**:
- All event features are opt-in (no breaking changes)
- Services without `emits` declarations work exactly as before
- No changes to existing public APIs

**Dependencies**:
- May need `concurrent-ruby` gem for thread-safe Bus registry
- Async features already depend on ActiveJob (no new dependencies)

**Phasing Approach**:
- Phases 1-2 can be merged as single PR (core functionality)
- Phase 3 requires Rails integration testing (separate PR recommended)
- Phases 4-6 are polish/DX improvements (can be bundled or separate)

