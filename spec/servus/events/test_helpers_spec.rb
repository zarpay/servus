# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Servus::Testing::EventHelpers do
  include described_class

  after do
    Servus::Events::Bus.clear
  end

  describe 'servus_expect_event matcher' do
    it 'passes when event is emitted with matching payload' do
      service_class = stub_const('TestService', Class.new(Servus::Base) do
        emits :user_created, on: :success

        def call
          success({ user_id: 123, email: 'test@example.com' })
        end
      end)

      servus_expect_event(:user_created)
        .with_payload(hash_including(user_id: 123))
        .when { service_class.call }
    end

    it 'fails when event is not emitted' do
      service_class = stub_const('TestService', Class.new(Servus::Base) do
        def call
          success({})
        end
      end)

      expect do
        servus_expect_event(:user_created)
          .with_payload({})
          .when { service_class.call }
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /expected.*:user_created.*to be emitted/)
    end

    it 'fails when event is emitted with wrong name' do
      service_class = stub_const('TestService', Class.new(Servus::Base) do
        emits :account_created, on: :success

        def call
          success({})
        end
      end)

      expect do
        servus_expect_event(:user_created)
          .with_payload({})
          .when { service_class.call }
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
        servus_expect_event(:user_created)
          .with_payload(hash_including(user_id: 123))
          .when { service_class.call }
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError)
    end
  end
end
