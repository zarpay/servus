# frozen_string_literal: true

# Servus namespace
module Servus
  # Configuration settings for the Servus gem.
  #
  # Manages global configuration options including schema file locations.
  # Access the configuration via {Servus.config} or modify via {Servus.configure}.
  #
  # @example Customizing schema location
  #   Servus.configure do |config|
  #     config.schema_root = Rails.root.join('lib/schemas')
  #   end
  #
  # @see Servus.config
  # @see Servus.configure
  class Config
    # The directory where JSON schema files are located.
    #
    # Defaults to `Rails.root/app/schemas/services` in Rails applications.
    #
    # @return [String] the schemas directory path
    attr_accessor :schemas_dir

    # The directory where event handlers are located.
    #
    # Defaults to `Rails.root/app/events` in Rails applications.
    #
    # @return [String] the events directory path
    attr_accessor :events_dir

    # The directory where services are located.
    #
    # Defaults to `Rails.root/app/services` in Rails applications.
    #
    # @return [String] the services directory path
    attr_accessor :services_dir

    # Whether to validate that all event handlers subscribe to events that are actually emitted by services.
    #
    # When enabled, raises an error on boot if handlers subscribe to non-existent events.
    # Helps catch typos and orphaned handlers.
    #
    # @return [Boolean] true to validate, false to skip validation
    attr_accessor :strict_event_validation

    # The directory where guard classes are located.
    #
    # Defaults to `Rails.root/app/guards` in Rails applications.
    #
    # @return [String] the guards directory path
    attr_accessor :guards_dir

    # The directory where generated spec/test files are placed.
    #
    # Defaults to `"spec"`. Projects using Minitest or a custom test layout
    # can override this (e.g., `"test"`) so generators write files into the
    # correct location.
    #
    # @return [String] the tests directory path
    attr_accessor :tests_dir

    # Whether to include the default built-in guards (EnsurePresent, EnsurePositive).
    #
    # @return [Boolean] true to include default guards, false to exclude them
    attr_accessor :include_default_guards

    # Whether to require all services to define an arguments schema.
    #
    # When enabled, raises {Servus::Support::Errors::SchemaRequiredError} when
    # a service is called without an arguments schema defined.
    #
    # @return [Boolean] true to require arguments schemas, false to allow schema-less services
    attr_accessor :require_service_arguments_schema

    # Whether to require all services to define a result schema.
    #
    # When enabled, raises {Servus::Support::Errors::SchemaRequiredError} when
    # a service returns a successful response without a result schema defined.
    # Failure schemas remain optional regardless of this setting.
    #
    # @return [Boolean] true to require result schemas, false to allow schema-less services
    attr_accessor :require_service_result_schema

    # Whether to require all event handlers to define a payload schema.
    #
    # When enabled, raises {Servus::Support::Errors::SchemaRequiredError} when
    # an event handler validates a payload without a payload schema defined.
    #
    # @return [Boolean] true to require payload schemas, false to allow schema-less handlers
    attr_accessor :require_event_payload_schema

    # Whether external instantiation of services is blocked and instance
    # `#call` methods are automatically privatized.
    #
    # When enabled (default), callers must invoke services via the class
    # method {Servus::Base.call}, which runs argument validation, logging,
    # benchmarking, guards, result validation, and event emission. Calling
    # `MyService.new` or `instance.call` directly raises `NoMethodError`.
    #
    # Disable this if you have existing code that instantiates services
    # directly or otherwise prefer to opt out of the enforcement.
    #
    # @return [Boolean] true to enforce lockdown (default), false to allow
    #   direct instantiation and public instance `#call`
    # @see Servus::Support::Lockdown
    attr_reader :lockdown_enabled

    # Sets whether lockdown is enforced, immediately re-applying the
    # resulting `.new` visibility to {Servus::Base}.
    #
    # @param value [Boolean] the new lockdown setting
    # @return [Boolean] the new value
    def lockdown_enabled=(value)
      @lockdown_enabled = value
      Servus::Base.apply_lockdown!
    end

    # Initializes a new configuration with default values.
    #
    # @api private
    def initialize
      @guards_dir   = 'app/guards'
      @events_dir   = 'app/events'
      @schemas_dir  = 'app/schemas'
      @services_dir = 'app/services'
      @tests_dir    = 'spec'

      @strict_event_validation = true
      @include_default_guards  = true
      @lockdown_enabled        = true

      @require_service_arguments_schema = false
      @require_service_result_schema    = false
      @require_event_payload_schema     = false
    end

    # Returns the full path to a service's schema file.
    #
    # @param service_namespace [String] underscored service namespace (e.g., "process_payment")
    # @param type [String] schema type ("arguments" or "result")
    # @return [String] full path to the schema JSON file
    #
    # @example
    #   config.schema_path_for("process_payment", "arguments")
    #   # => "/full/path/app/schemas/process_payment/arguments.json"
    def schema_path_for(service_namespace, type)
      File.join(root_path, schemas_dir, service_namespace, "#{type}.json")
    end

    # Returns the directory containing a service's schema files.
    #
    # @param service_namespace [String] underscored service namespace
    # @return [String] directory path for the service's schemas
    #
    # @example
    #   config.schema_dir_for("process_payment")
    #   # => "/full/path/app/schemas/process_payment"
    def schema_dir_for(service_namespace)
      File.join(root_path, schemas_dir, service_namespace)
    end

    private

    # Determines the application root path.
    #
    # @return [String] Rails.root in Rails apps, or gem's root directory otherwise
    # @api private
    def root_path
      if defined?(Rails) && Rails.respond_to?(:root)
        Rails.root
      else
        File.expand_path('../../..', __dir__)
      end
    end
  end

  # Returns the singleton configuration instance.
  #
  # @return [Servus::Config] the global configuration object
  #
  # @example
  #   Servus.config.schema_root
  #   # => "/app/app/schemas/services"
  def self.config
    @config ||= Config.new
  end

  # Yields the configuration for modification.
  #
  # @yieldparam config [Servus::Config] the configuration object to modify
  # @return [void]
  #
  # @example
  #   Servus.configure do |config|
  #     config.schema_root = Rails.root.join('custom/schemas')
  #   end
  def self.configure
    yield(config)
  end
end
