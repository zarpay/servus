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

# --- Async extension fixtures ------------------------------------------------
#
# Real, top-level service constants so the async extension generates stable,
# uniquely-named job classes (e.g. AsyncEmailService -> AsyncEmailServiceJob)
# that persist for the whole suite — no per-example constant juggling. Each
# `.async(...)` fixture is dedicated to a single example so configuring its job
# class can't leak into others.
class AsyncFixtureService < Servus::Base
  def initialize(**args)
    super()
    @args = args
  end

  def call
    success(@args)
  end
end

# Each fixture below is dedicated to a single concern so configuring its
# generated job class (queue, priority, retries) can't leak between examples:
# AsyncEmailService drives call_async + job perform; AsyncQueueService,
# AsyncPriorityService, AsyncBlockService and AsyncRetryService each exercise one
# facet of the `.async` DSL.
class AsyncEmailService < AsyncFixtureService; end
class AsyncQueueService < AsyncFixtureService; end
class AsyncPriorityService < AsyncFixtureService; end
class AsyncBlockService < AsyncFixtureService; end
class AsyncRetryService < AsyncFixtureService; end

# Namespaced fixture — its sibling job is AsyncNamespace::DeliverServiceJob.
module AsyncNamespace
  class DeliverService < AsyncFixtureService; end
end
