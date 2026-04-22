# frozen_string_literal: true

# Globals
require 'json-schema'
require 'active_support'
require 'active_support/core_ext/class/attribute'
require 'active_model_serializers'

# Servus namespace
module Servus; end

# Helpers
require_relative 'servus/helpers/controller_helpers'

# Railtie
require_relative 'servus/railtie' if defined?(Rails::Railtie)

# Config
require_relative 'servus/config'

# Support
require_relative 'servus/support/logger'
require_relative 'servus/support/data_object'
require_relative 'servus/support/response'
require_relative 'servus/support/validator'
require_relative 'servus/support/errors'
require_relative 'servus/support/rescuer'
require_relative 'servus/support/lockdown'
require_relative 'servus/support/message_resolver'

# Events
require_relative 'servus/events/errors'
require_relative 'servus/events/bus'
require_relative 'servus/events/emitter'
require_relative 'servus/event_handler'

# Guards (guards.rb loads defaults based on config)
require_relative 'servus/guard'
require_relative 'servus/guards'

# Core
require_relative 'servus/version'
require_relative 'servus/base'

# Service helpers (mixed into Base, so must load after base.rb)
require_relative 'servus/helpers/service_helpers'
