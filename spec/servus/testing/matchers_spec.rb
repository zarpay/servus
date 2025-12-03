# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Servus Testing Matchers' do
  after do
    Servus::Events::Bus.clear
  end

  describe 'emit_event matcher' do
    it 'passes when event is emitted with matching payload' do
      service_class = stub_const('TestService', Class.new(Servus::Base) do
        emits :user_created, on: :success

        def call
          success({ user_id: 123, email: 'test@example.com' })
        end
      end)

      expect { service_class.call }.to emit_event(:user_created).with(hash_including(user_id: 123))
    end

    it 'fails when event is not emitted' do
      service_class = stub_const('TestService', Class.new(Servus::Base) do
        def call
          success({})
        end
      end)

      expect do
        expect { service_class.call }.to emit_event(:user_created)
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /expected.*:user_created.*to be emitted/)
    end

    it 'fails when payload does not match' do
      service_class = stub_const('TestService', Class.new(Servus::Base) do
        emits :user_created, on: :success

        def call
          success({ user_id: 999 })
        end
      end)

      expect do
        expect { service_class.call }.to emit_event(:user_created).with(hash_including(user_id: 123))
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError)
    end
  end

  describe 'call_service matcher' do
    it 'passes when service is called with matching arguments' do
      service_class = Class.new(Servus::Base) do
        def self.call(**args)
          Servus::Support::Response.new(true, args, nil)
        end
      end

      expect { service_class.call(user_id: 123) }.to call_service(service_class).with(user_id: 123)
    end

    it 'passes when async service is called' do
      service_class = Class.new(Servus::Base) do
        def self.call_async(**args)
          { args: args }
        end
      end

      expect { service_class.call_async(user_id: 456) }.to call_service(service_class).with(user_id: 456).async
    end
  end
end
