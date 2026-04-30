# frozen_string_literal: true

module Servus
  module Support
    # Resolves message templates with interpolation support.
    #
    # Handles multiple template formats:
    # - String: Static or with %{key} / %<key>s interpolation
    # - Symbol: I18n key lookup with fallback
    # - Hash: Inline translations keyed by locale
    # - Proc: Dynamic template evaluated at runtime
    #
    # @example Basic string interpolation
    #   resolver = MessageResolver.new(
    #     template: 'Hello, %<name>s!',
    #     data: { name: 'World' }
    #   )
    #   resolver.resolve # => "Hello, World!"
    #
    # @example With I18n symbol
    #   resolver = MessageResolver.new(template: :greeting)
    #   resolver.resolve # => I18n.t('greeting') or "Greeting" fallback
    #
    # @example With inline translations
    #   resolver = MessageResolver.new(
    #     template: { en: 'Hello', es: 'Hola' }
    #   )
    #   resolver.resolve # => "Hello" (or "Hola" if I18n.locale == :es)
    #
    # @example With proc and context
    #   resolver = MessageResolver.new(
    #     template: -> { "Balance: #{balance}" }
    #   )
    #   resolver.resolve(context: account) # => "Balance: 100"
    #
    class MessageResolver
      # @return [String, Symbol, Hash, Proc, nil] the message template
      attr_reader :template

      # @return [Hash, Proc, nil] the interpolation data or data-providing block
      attr_reader :data

      # @return [String, nil] the I18n scope prefix for symbol templates
      attr_reader :i18n_scope

      # Creates a new message resolver.
      #
      # @param template [String, Symbol, Hash, Proc, nil] the message template
      # @param data [Hash, Proc, nil] interpolation data or block returning data
      # @param i18n_scope [String] prefix for I18n lookups (default: nil)
      def initialize(template:, data: nil, i18n_scope: nil)
        @template   = template
        @data       = data
        @i18n_scope = i18n_scope
      end

      # Resolves the template to a final string.
      #
      # @param context [Object, nil] object for evaluating Proc templates/data blocks
      # @return [String] the resolved and interpolated message
      def resolve(context: nil)
        resolved_template = resolve_template(context)
        resolved_data     = resolve_data(context)

        interpolate(resolved_template, resolved_data)
      end

      private

      # Resolves the template to a string based on its type.
      #
      # @param context [Object, nil] evaluation context for Proc templates
      # @return [String] the resolved template string
      def resolve_template(context)
        case template
        when Symbol then resolve_i18n_template
        when Proc   then resolve_proc_template(context)
        when Hash   then resolve_locale_template
        else             template.to_s
        end
      end

      # Resolves I18n symbol template with fallback.
      #
      # @return [String] the translated string or humanized fallback
      def resolve_i18n_template
        key = build_i18n_key
        fallback = humanize_symbol(template)

        if defined?(I18n)
          I18n.t(key, default: fallback)
        else
          fallback
        end
      end

      # Builds the full I18n key from template and scope.
      #
      # @return [String, Symbol] the I18n lookup key
      def build_i18n_key
        return template if template.to_s.include?('.')
        return template unless i18n_scope

        "#{i18n_scope}.#{template}"
      end

      # Converts a symbol to a human-readable string.
      #
      # @param sym [Symbol] the symbol to humanize
      # @return [String] humanized string
      def humanize_symbol(sym)
        sym.to_s.tr('_', ' ').capitalize
      end

      # Evaluates a Proc template in the given context.
      #
      # @param context [Object, nil] the evaluation context
      # @return [String] the proc result as string
      def resolve_proc_template(context)
        result = context ? context.instance_exec(&template) : template.call
        result.to_s
      end

      # Resolves a Hash template by current locale.
      #
      # @return [String] the localized string
      def resolve_locale_template
        locale = current_locale
        (template[locale] || template[:en] || template.values.first).to_s
      end

      # Returns the current I18n locale or :en.
      #
      # @return [Symbol] the current locale
      def current_locale
        defined?(I18n) ? I18n.locale : :en
      end

      # Resolves data to a Hash for interpolation.
      #
      # @param context [Object, nil] evaluation context for Proc data
      # @return [Hash] the interpolation data
      def resolve_data(context)
        case data
        when Proc then context ? context.instance_exec(&data) : data.call
        when Hash then data
        else           {}
        end
      end

      # Interpolates data into the template string.
      #
      # @param template_str [String] the template with placeholders
      # @param data_hash [Hash] the interpolation data
      # @return [String] the interpolated string
      def interpolate(template_str, data_hash)
        return template_str if data_hash.empty?

        template_str % data_hash
      rescue KeyError, ArgumentError => e
        warn "MessageResolver interpolation failed: #{e.message}"
        template_str
      end
    end
  end
end
