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
require_relative 'servus/support/response'
require_relative 'servus/support/validator'
require_relative 'servus/support/errors'
require_relative 'servus/support/rescuer'

# Core
require_relative 'servus/version'
require_relative 'servus/base'
