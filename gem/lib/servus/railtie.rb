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
        Servus::Base.extend Servus::Extensions::Async::Call
      end
    end

    initializer 'servus.lazily' do
      ActiveSupport.on_load(:active_record) do
        require 'servus/extensions/lazily/ext'
        Servus::Base.extend Servus::Extensions::Lazily::Call
      end
    end

    # Load guards and event handlers, clear caches on reload
    config.to_prepare do
      # Load custom guards from guards_dir
      guards_path = Rails.root.join(Servus.config.guards_dir)
      if Dir.exist?(guards_path)
        Dir[File.join(guards_path, '**/*_guard.rb')].each do |file|
          require_dependency file
        end
      end

      Servus::Events::Bus.clear if Rails.env.development?

      # Eager load all event handlers
      events_path = Rails.root.join(Servus.config.events_dir)
      Dir[File.join(events_path, '**/*_handler.rb')].each do |file|
        require_dependency file
      end
    end

    # NOTE: Event validation is available but not run automatically due to load order issues.
    # To validate handlers match emitted events, call manually:
    #   Servus::EventHandler.validate_all_handlers!
    # Or create a rake task for CI validation.
  end
end
