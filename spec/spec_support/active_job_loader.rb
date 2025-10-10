require 'active_job'
require 'active_job/base'
# Trigger ActiveJob load hook manually — Rails normally does this.
ActiveSupport.run_load_hooks(:active_job, ActiveJob::Base)
require 'servus/railtie'

