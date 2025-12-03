# frozen_string_literal: true

module Servus
  module Events
    # Raised when an event handler subscribes to an event that no service emits.
    #
    # This helps catch typos in event names and orphaned handlers.
    class OrphanedHandlerError < StandardError; end
  end
end
