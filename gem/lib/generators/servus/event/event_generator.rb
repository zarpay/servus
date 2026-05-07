# frozen_string_literal: true

module Servus
  module Generators
    # Rails generator for creating Servus event classes.
    #
    # Generates an event class and spec file. The event name is inferred
    # from the class name — no explicit +event_name+ call needed.
    #
    # @example Generate an event
    #   rails g servus:event referral_verified
    #
    # @example Generated files
    #   app/events/referral_verified.rb
    #   spec/app/events/referral_verified_spec.rb
    #
    # @see https://guides.rubyonrails.org/generators.html
    class EventGenerator < Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)

      class_option :no_docs, type: :boolean,
                             default: false,
                             desc: 'Skip documentation comments in generated files'

      # Creates the event class and spec files.
      #
      # @return [void]
      def create_event_file
        template 'event.rb.erb', event_path
        template 'event_spec.rb.erb', event_spec_path
      end

      private

      # @return [String] event file path
      # @api private
      def event_path
        File.join(Servus.config.events_dir, "#{file_name}.rb")
      end

      # @return [String] spec file path
      # @api private
      def event_spec_path
        File.join(Servus.config.tests_dir, Servus.config.events_dir, "#{file_name}_spec.rb")
      end

      # @return [String] event class name (e.g. "ReferralVerified")
      # @api private
      def event_class_name
        class_name
      end
    end
  end
end
