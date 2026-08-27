# frozen_string_literal: true

require "rails_helper"

# =============================================================================
# Calling a service asynchronously
# =============================================================================
#
# Features exercised:
#   - .call_async, with and without scheduling options
#   - The `async` DSL: queue, priority, and the block form
#   - The generated named job class
#   - The reserved-keyword trap
#
# -----------------------------------------------------------------------------
# A named job per service
# -----------------------------------------------------------------------------
#
# Servus generates one ActiveJob class per service, named after it, as a
# sibling constant: Treasury::TransferGold::Service gets
# Treasury::TransferGold::ServiceJob.
#
# You never write or reference it. It exists so a Sidekiq or GoodJob dashboard
# shows which service ran, rather than one generic wrapper for everything in
# the app — which is what makes per-queue metrics and retry policies useful.
RSpec.describe "asynchronous execution" do
  let(:house) { create(:house) }

  # ---------------------------------------------------------------------------
  # Why this reference is here
  # ---------------------------------------------------------------------------
  #
  # `Treasury::TransferGold::ServiceJob` is not a file on disk — Servus creates
  # it in the service's `inherited` hook, when the SERVICE class loads. So
  # Zeitwerk cannot autoload the job constant on demand: referencing it before
  # anything has touched the service raises NameError.
  #
  # Production eager loading makes this invisible, because every service is
  # loaded at boot. In a spec that names a job without naming its service, it
  # bites. Touching the service first is the fix.
  before do
    Treasury::TransferGold::Service
    Ravens::DispatchMessage::Service
  end

  describe "the generated job class" do
    it "is a sibling constant named after the service" do
      expect(Treasury::TransferGold::ServiceJob.name)
        .to eq("Treasury::TransferGold::ServiceJob")
    end

    it "knows which service it runs" do
      expect(Treasury::TransferGold::ServiceJob.servus_service)
        .to eq(Treasury::TransferGold::Service)
    end

    # Anonymous services cannot be enqueued: ActiveJob resolves a job on the
    # worker by its serialized class name, and an anonymous class has none.
    it "cannot be generated for an anonymous service" do
      expect { Class.new(Servus::Base).call_async(x: 1) }
        .to raise_error(Servus::Events::Errors::AnonymousServiceError, /anonymous/)
    end
  end

  describe "the async DSL" do
    # Keyword form: class-level defaults for the generated job.
    it "applies the declared queue and priority" do
      expect(Treasury::TransferGold::ServiceJob.queue_name).to eq("treasury")
      expect(Treasury::TransferGold::ServiceJob.priority).to eq(5)
    end

    # Block form: class_eval'd on the job, so the whole ActiveJob surface is
    # available — retry_on, discard_on, callbacks.
    it "applies the block form's retry policy" do
      expect(Treasury::TransferGold::ServiceJob.rescue_handlers.map(&:first))
        .to include("ActiveRecord::Deadlocked")
    end

    it "gives each service its own queue" do
      expect(Ravens::DispatchMessage::ServiceJob.queue_name).to eq("ravens")
    end
  end

  describe ".call_async" do
    it "enqueues rather than running" do
      expect { Ravens::DispatchMessage::Service.call_async(house_id: house.id, message: "Later") }
        .to have_enqueued_job(Ravens::DispatchMessage::ServiceJob)
        .with(house_id: house.id, message: "Later")
    end

    it "does not run the service" do
      expect { Ravens::DispatchMessage::Service.call_async(house_id: house.id, message: "Later") }
        .not_to change(Raven, :count)
    end

    # Inline options layer on top of the class-level `async` defaults and win
    # for that one enqueue.
    it "lets an inline queue override the declared one" do
      expect { Ravens::DispatchMessage::Service.call_async(house_id: house.id, message: "x", queue: :urgent) }
        .to have_enqueued_job(Ravens::DispatchMessage::ServiceJob).on_queue("urgent")
    end

    it "accepts a delay" do
      freeze_time do
        expect { Ravens::DispatchMessage::Service.call_async(house_id: house.id, message: "x", wait: 10.minutes) }
          .to have_enqueued_job(Ravens::DispatchMessage::ServiceJob).at(10.minutes.from_now)
      end
    end

    # -------------------------------------------------------------------------
    # The reserved-keyword trap
    # -------------------------------------------------------------------------
    #
    # `call_async` pulls :wait, :wait_until, :queue, :priority, and
    # :job_options out of the arguments and treats them as scheduling options.
    # They are then REMOVED from what the service receives.
    #
    # So a service with a legitimate argument called `queue` or `priority`
    # cannot be called asynchronously with it — the value is silently eaten and
    # the service sees the argument as missing.
    #
    # The lesson is a naming one: avoid those five names for service arguments.
    it "swallows a service argument that collides with a scheduling option" do
      collider = stub_const("QueueColliderService", Class.new(ApplicationService) do
        schema arguments: { type: "object", required: %w[queue], properties: { queue: { "type" => "string" } } }

        def initialize(queue:) = @queue = queue
        def call = success(queue: @queue)
      end)

      # Called synchronously it works exactly as written.
      expect(collider.call(queue: "ravens")).to be_service_success

      # Force the job class into existence before naming it in the matcher.
      # For a class defined at load time the `inherited` hook does this eagerly,
      # but this one was anonymous when it was created and only named afterwards
      # by stub_const — so its job is generated lazily, on first use.
      job_class = collider.servus_job_class

      # Called asynchronously the value is taken as the JOB's queue and removed
      # from the arguments — so the job is enqueued on "ravens" with NO
      # arguments at all, and the service will fail its own argument schema
      # whenever the job eventually runs.
      expect { collider.call_async(queue: "ravens") }
        .to have_enqueued_job(job_class).on_queue("ravens").with(no_args)
    end

    # The same collision, seen from the other end: run the job and the missing
    # argument surfaces as a validation error far from the call site that
    # caused it.
    it "fails inside the job when the swallowed argument was required", :inline_jobs do
      collider = stub_const("InlineColliderService", Class.new(ApplicationService) do
        schema arguments: { type: "object", required: %w[queue], properties: { queue: { "type" => "string" } } }

        def initialize(queue:) = @queue = queue
        def call = success(queue: @queue)
      end)

      expect { collider.call_async(queue: "ravens") }
        .to raise_error(Servus::Support::Errors::ValidationError, /queue/)
    end
  end

  describe "running the job", :inline_jobs do
    # With the inline adapter the job executes on enqueue, which routes back
    # through Servus::Base.call — so validation, guards, logging, and event
    # emission all run exactly as they would synchronously.
    it "runs the full service lifecycle" do
      expect { Ravens::DispatchMessage::Service.call_async(house_id: house.id, message: "Now") }
        .to change(Raven, :count).by(1)
    end

    it "still validates arguments inside the job" do
      expect { Ravens::DispatchMessage::Service.call_async(house_id: house.id) }
        .to raise_error(Servus::Support::Errors::ValidationError, /message/)
    end
  end
end
