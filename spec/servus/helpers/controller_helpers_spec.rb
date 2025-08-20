# frozen_string_literal: true

# spec/helpers/controller_helpers_spec.rb

require 'spec_helper'
require 'action_controller'
require 'servus/helpers/controller_helpers'

RSpec.describe Servus::Helpers::ControllerHelpers do
  # Create a test controller class that includes the controller helpers
  controller_class = Class.new(ActionController::Base) do
    include Servus::Helpers::ControllerHelpers

    attr_reader :rendered

    # Stub `render` to capture what would be rendered
    def render(options)
      @rendered = options
    end
  end

  error_class = Class.new(StandardError) do
    def api_error
      { code: :bad_request, message: 'Bad Request' }
    end
  end

  let(:controller) { controller_class.new }

  let(:fake_service_success) do
    Class.new do
      def self.call(**)
        Servus::Support::Response.new(true, { hello: 'world' }, nil)
      end
    end
  end

  let(:fake_service_failure) do
    Class.new do
      define_singleton_method(:call) do |**_args|
        Servus::Support::Response.new(false, nil, error_class.new)
      end
    end
  end

  describe '#run_service' do
    it 'does not render error if result is successful' do
      controller.run_service(fake_service_success, {})

      expect(controller.instance_variable_get(:@result).error).to be_nil
      expect(controller.instance_variable_get(:@result).success?).to be true
      expect(controller.instance_variable_get(:@result).data).to eq({ hello: 'world' })

      expect(controller.instance_variable_get(:@rendered)).to be_nil
    end

    it 'renders error if result is not successful' do
      controller.run_service(fake_service_failure, {})

      expect(controller.instance_variable_get(:@result).error).to be_a(error_class)
      expect(controller.instance_variable_get(:@result).success?).to be false
      expect(controller.instance_variable_get(:@result).data).to be_nil

      expect(controller.instance_variable_get(:@rendered)).to eq(
        json: { code: :bad_request, message: 'Bad Request' },
        status: :bad_request
      )
    end
  end

  describe '#render_service_object_error' do
    it 'renders error' do
      controller.render_service_object_error(error_class.new.api_error)

      expect(controller.instance_variable_get(:@rendered)).to eq(
        json: { code: :bad_request, message: 'Bad Request' },
        status: :bad_request
      )
    end
  end
end
