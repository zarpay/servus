# frozen_string_literal: true

class TrackingService < Servus::Base
  class << self
    def calls
      @calls ||= []
    end

    def last_call
      calls.last
    end

    def reset!
      @calls = []
    end
  end

  def initialize(**args)
    @args = args
  end

  def call
    self.class.calls << @args
    success(@args)
  end
end

class ServiceA < TrackingService; end
class ServiceB < TrackingService; end

class UserCreatedEvent < Servus::Event
  event_name :user_created

  invoke ServiceA
end
