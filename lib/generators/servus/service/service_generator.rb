# frozen_string_literal: true

module Servus
  module Generators
    # Rails generator for creating Servus service objects.
    #
    # Generates a complete service structure including:
    # - Service class file
    # - RSpec test file
    # - JSON schema files for arguments and results
    #
    # @example Generate a service
    #   rails g servus:service namespace/do_something_helpful user amount
    #
    # @example Generated files
    #   app/services/namespace/do_something_helpful/service.rb
    #   spec/services/namespace/do_something_helpful/service_spec.rb
    #   app/schemas/services/namespace/do_something_helpful/arguments.json
    #   app/schemas/services/namespace/do_something_helpful/result.json
    #
    # @see https://guides.rubyonrails.org/generators.html
    class ServiceGenerator < Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)

      argument :parameters, type: :array, default: [], banner: 'parameter'

      class_option :no_docs, type: :boolean,
                             default: false,
                             desc: 'Skip documentation comments in generated files'

      # Creates all service-related files.
      #
      # Generates the service class, spec file, and schema files from templates.
      #
      # @return [void]
      def create_service_file
        template 'service.rb.erb', service_path
        template 'service_spec.rb.erb', service_path_spec

        # Template json schemas
        template 'result.json.erb', service_result_schema_path
        template 'arguments.json.erb', service_arguments_shecma_path
      end

      private

      # Returns the path for the service file.
      #
      # @return [String] service file path
      # @api private
      def service_path
        "app/services/#{file_path}/service.rb"
      end

      # Returns the path for the service spec file.
      #
      # @return [String] spec file path
      # @api private
      def service_path_spec
        "spec/services/#{file_path}/service_spec.rb"
      end

      # Returns the path for the result schema file.
      #
      # @return [String] result schema path
      # @api private
      def service_result_schema_path
        "app/schemas/services/#{file_path}/result.json"
      end

      # Returns the path for the arguments schema file.
      #
      # @return [String] arguments schema path
      # @api private
      def service_arguments_shecma_path
        "app/schemas/services/#{file_path}/arguments.json"
      end

      # Returns the service class name with ::Service appended.
      #
      # @return [String] service class name
      # @api private
      def service_class_name
        "#{class_name}::Service"
      end

      # Returns the fully-qualified service class name.
      #
      # @return [String] fully-qualified class name
      # @api private
      def service_full_class_name
        service_class_name.include?('::') ? service_class_name : "::#{service_class_name}"
      end

      # Generates the parameter list for the initialize method.
      #
      # @return [String] parameter list with keyword syntax
      # @example
      #   parameter_list # => "(user:, amount:)"
      # @api private
      def parameter_list
        return '' if parameters.empty?

        "(#{parameters.map { |param| "#{param}:" }.join(', ')})"
      end

      # Generates instance variable assignments for initialize method.
      #
      # @return [String] multi-line instance variable assignments
      # @example
      #   initialize_params # => "@user = user\n    @amount = amount"
      # @api private
      def initialize_params
        parameters.map { |param| "@#{param} = #{param}" }.join("\n    ")
      end

      # Generates attr_reader declarations for parameters.
      #
      # @return [String] attr_reader declaration or empty string
      # @example
      #   attr_readers # => "attr_reader :user, :amount"
      # @api private
      def attr_readers
        return '' if parameters.empty?

        "attr_reader #{parameters.map { |param| ":#{param}" }.join(', ')}"
      end
    end
  end
end
