# frozen_string_literal: true

require 'rails/railtie'

module Servus
  # Railtie for Rails integration
  class Railtie < Rails::Railtie
    initializer 'servus.controller_helpers' do
      ActiveSupport.on_load(:action_controller) do
        include Servus::Helpers::ControllerHelpers
      end
    end

    initializer 'servus.job_async' do
      ActiveSupport.on_load(:active_job) do
        require 'servus/extensions/async/ext'
        # Extend the base service with the async call method
        Servus::Base.extend Servus::Extensions::Async::Call
      end
    end

    # Clear event handlers on code reload in development
    config.to_prepare do
      Servus::Events::Bus.clear if Rails.env.development?
    end

    # Validate event handlers after application loads
    config.after_initialize do
      Servus::EventHandler.validate_all_handlers!
    end
  end
end
