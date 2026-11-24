# frozen_string_literal: true

require 'spec_helper'
require 'servus/extensions/async/ext'

RSpec.describe 'Servus notifications' do
  def notifications(pattern)
    events = []
    ActiveSupport::Notifications.subscribed(->(event) { events << event }, pattern) do
      yield
    rescue StandardError
      nil
    end
    events
  end

  def service(name, &)
    stub_const(name, Class.new(Servus::Base, &))
  end

  let(:payload_event) do
    stub_const('InstrumentedEvent', Class.new(Servus::Event) do
      event_name :instrumented

      schema payload: { type: 'object', required: ['id'], properties: { id: { type: 'integer' } } }
    end)
  end

  after { Servus::Events::Bus.clear }

  describe 'call.servus' do
    it 'reports a success with the service, its args and the response' do
      greeter = service('Greeter') do
        def initialize(name:) = @name = name
        def call = success({ greeting: "Hi #{@name}" })
      end

      event = notifications('call.servus') { greeter.call(name: 'Ada') }.sole

      expect(event.payload).to include(service: greeter, args: { name: 'Ada' }, outcome: :success)
      expect(event.payload[:response].data).to eq({ greeting: 'Hi Ada' })
    end

    it 'reports a failure response as :failure' do
      failing = service('Failing') { def call = failure('nope') }

      event = notifications('call.servus') { failing.call }.sole

      expect(event.payload).to include(outcome: :failure)
      expect(event.payload[:response].error.message).to eq('nope')
    end

    it 'reports failure! as :failure' do
      failing = service('FailingBang') { def call = failure!('nope') }

      expect(notifications('call.servus') { failing.call }.sole.payload).to include(outcome: :failure)
    end

    it 'reports a failed guard as :guard' do
      guarded = service('Guarded') do
        def call
          enforce_presence!(name: nil)
          success({})
        end
      end

      event = notifications('call.servus') { guarded.call }.sole

      expect(event.payload).to include(outcome: :guard)
      expect(event.payload[:response].error).to be_a(Servus::Support::Errors::GuardError)
    end

    it 'reports arguments that fail their schema as :invalid_arguments' do
      strict = service('StrictArguments') do
        schema arguments: { type: 'object', properties: { id: { type: 'integer' } } }

        def initialize(id:) = @id = id
        def call = success({})
      end

      event = notifications('call.servus') { strict.call(id: 'x') }.sole

      expect(event.payload).to include(outcome: :invalid_arguments)
      expect(event.payload[:exception_object]).to be_a(Servus::Support::Errors::ValidationError)
    end

    it 'reports a result that fails its schema as :invalid_result' do
      strict = service('StrictResult') do
        schema result: { type: 'object', required: ['id'] }

        def call = success({})
      end

      event = notifications('call.servus') { strict.call }.sole

      expect(event.payload).to include(outcome: :invalid_result)
      expect(event.payload[:exception_object]).to be_a(Servus::Support::Errors::ValidationError)
    end

    it 'reports an emitted event payload that fails its schema as :invalid_event' do
      payload_event
      emitting = service('BadEmitter') do
        emits :instrumented, on: :success, with: ->(_) { { id: 'x' } }

        def call = success({})
      end

      event = notifications('call.servus') { emitting.call }.sole

      expect(event.payload).to include(outcome: :invalid_event)
      expect(event.payload[:exception_object]).to be_a(Servus::Support::Errors::ValidationError)
    end

    it 'reports an event emitted from the body with a payload that fails its schema as :invalid_event' do
      event_class = payload_event
      emitting = service('BodyEmitter') do
        define_method(:call) do
          event_class.emit({ id: 'x' })
          success({})
        end
      end

      expect(notifications('call.servus') { emitting.call }.sole.payload).to include(outcome: :invalid_event)
    end

    it 'reports any other raised error as :exception' do
      raising = service('Raising') { def call = raise(ArgumentError, 'boom') }

      event = notifications('call.servus') { raising.call }.sole

      expect(event.payload).to include(outcome: :exception)
      expect(event.payload[:exception_object]).to be_a(ArgumentError)
      expect(event.payload).not_to have_key(:response)
    end

    it 'reports a ValidationError raised from the body as :exception' do
      raising = service('RaisingValidation') do
        def call = raise(Servus::Support::Errors::ValidationError, 'body')
      end

      expect(notifications('call.servus') { raising.call }.sole.payload).to include(outcome: :exception)
    end

    it 'reports an exception that rescue_from handles as the failure the caller gets' do
      rescued = service('Rescued') do
        rescue_from ArgumentError

        def call = raise(ArgumentError, 'boom')
      end

      event = notifications('call.servus') { rescued.call }.sole

      expect(event.payload).to include(outcome: :failure)
      expect(event.payload).not_to have_key(:exception_object)
      expect(event.payload[:response].error.message).to eq('[ArgumentError]: boom')
    end

    it 'reports invalid arguments that rescue_from handles as :failure' do
      rescued = service('RescuedValidation') do
        schema arguments: { type: 'object', properties: { id: { type: 'integer' } } }
        rescue_from Servus::Support::Errors::ValidationError

        def initialize(id:) = @id = id
        def call = success({})
      end

      expect(notifications('call.servus') { rescued.call(id: 'x') }.sole.payload).to include(outcome: :failure)
    end

    it 'filters args with the configured log filter' do
      Servus.config.log_filter_parameters = %i[password]
      login = service('Login') do
        def initialize(**args) = @args = args
        def call = success({})
      end

      event = notifications('call.servus') { login.call(user: 'ada', password: 'secret') }.sole

      expect(event.payload[:args]).to eq({ user: 'ada', password: '[FILTERED]' })
    ensure
      Servus.config.log_filter_parameters = []
    end

    it 'reports a nested call before the call around it, each with its own outcome' do
      strict = service('StrictInner') do
        schema arguments: { type: 'object', properties: { id: { type: 'integer' } } }

        def initialize(id:) = @id = id
        def call = success({})
      end
      outer = service('Outer') do
        define_method(:call) { strict.call(id: 'x') }
      end

      events = notifications('call.servus') { outer.call }

      expect(events.map { |event| event.payload.values_at(:service, :outcome) })
        .to eq([[strict, :invalid_arguments], [outer, :exception]])
    end
  end

  describe 'enqueue.servus' do
    before { Servus::Base.extend(Servus::Extensions::Async::Call) }

    it 'reports the service, its args and the job' do
      event = notifications('enqueue.servus') { AsyncEmailService.call_async(to: 'ada', queue: :low) }.sole

      expect(event.payload).to include(service: AsyncEmailService, args: { to: 'ada' })
      expect(event.payload[:job]).to be_a(AsyncEmailServiceJob)
    end

    it 'filters args with the configured log filter' do
      Servus.config.log_filter_parameters = %i[token]

      event = notifications('enqueue.servus') { AsyncEmailService.call_async(to: 'ada', token: 't') }.sole

      expect(event.payload[:args]).to eq({ to: 'ada', token: '[FILTERED]' })
    ensure
      Servus.config.log_filter_parameters = []
    end

    it 'wraps the call when the job runs inline', :inline_jobs do
      events = notifications(/\.servus\z/) { AsyncEmailService.call_async(to: 'ada') }

      expect(events.map(&:name)).to eq(%w[call.servus enqueue.servus])
      expect(events.first.payload).to include(service: AsyncEmailService, outcome: :success)
    end
  end

  describe 'emit.servus' do
    it 'reports the event, the emitting service and the payload' do
      payload_event
      emitting = service('Emitter') do
        emits :instrumented, on: :success, with: ->(_) { { id: 1 } }

        def call = success({})
      end

      event = notifications('emit.servus') { emitting.call }.sole

      expect(event.payload).to eq(event: :instrumented, service: emitting, payload: { id: 1 })
    end

    it 'reports no service when the bus is called directly' do
      event = notifications('emit.servus') { Servus::Events::Bus.emit(:direct, { id: 1 }) }.sole

      expect(event.payload).to eq(event: :direct, service: nil, payload: { id: 1 })
    end

    it 'wraps the servus.events notification' do
      events = notifications(/\Aservus\.events\.|\Aemit\.servus\z/) { Servus::Events::Bus.emit(:direct, {}) }

      expect(events.map(&:name)).to eq(%w[servus.events.direct emit.servus])
    end
  end
end
