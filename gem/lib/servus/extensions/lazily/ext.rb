# frozen_string_literal: true

module Servus
  module Extensions
    # Lazy record resolution extensions for Servus services.
    #
    # This module provides the infrastructure for lazily resolving record
    # references (IDs or instances) in service inputs. When loaded, it extends
    # {Servus::Base} with the {Call#lazily} class method.
    #
    # @see Servus::Extensions::Lazily::Call
    module Lazily
      require 'servus/extensions/lazily/errors'
      require 'servus/extensions/lazily/resolver'
      require 'servus/extensions/lazily/call'

      # Extension module for lazily functionality.
      #
      # @api private
      module Ext; end
    end
  end
end
