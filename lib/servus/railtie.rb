# frozen_string_literal: true

# lib/servus/railtie.rb
require 'rails/railtie'

module Servus
  # Railtie for Rails integration
  class Railtie < Rails::Railtie
    initializer 'servus.controller_helpers' do
      ActiveSupport.on_load(:action_controller) do
        include Servus::Helpers::ControllerHelpers
      end
    end
  end
end
