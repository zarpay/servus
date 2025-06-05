# frozen_string_literal: true

module Servus
  module Generators
    # Servus Generator
    class ServiceGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      argument :parameters, type: :array, default: [], banner: "parameter"

      def create_service_file
        template "service.rb.erb", service_path
        template "service_spec.rb.erb", service_path_spec

        # Template json schemas
        template "result.json.erb", service_result_schema_path
        template "arguments.json.erb", service_arguments_shecma_path
      end

      private

      def service_path
        "app/services/#{file_path}/service.rb"
      end

      def service_path_spec
        "spec/services/#{file_path}/service_spec.rb"
      end

      def service_result_schema_path
        "app/schemas/services/#{file_path}/result.json"
      end

      def service_arguments_shecma_path
        "app/schemas/services/#{file_path}/arguments.json"
      end

      def service_class_name
        "#{class_name}::Service"
      end

      def service_full_class_name
        service_class_name.include?("::") ? service_class_name : "::#{service_class_name}"
      end

      def parameter_list
        return "" if parameters.empty?

        "(#{parameters.map { |param| "#{param}:" }.join(", ")})"
      end

      def initialize_params
        parameters.map { |param| "@#{param} = #{param}" }.join("\n    ")
      end

      def attr_readers
        return "" if parameters.empty?

        "attr_reader #{parameters.map { |param| ":#{param}" }.join(", ")}"
      end
    end
  end
end
