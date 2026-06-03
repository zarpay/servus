# frozen_string_literal: true

require_relative '../result'

module Servus
  module Support
    # Backwards-compatible alias for {Servus::Result}. The canonical class is
    # {Servus::Result}; this constant is kept so existing references continue
    # to resolve.
    Response = Servus::Result
  end
end
