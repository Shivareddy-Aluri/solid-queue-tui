# frozen_string_literal: true

require_relative "solid_queue_tui/version"

# Data layer
require_relative "solid_queue_tui/data/stats"
require_relative "solid_queue_tui/data/jobs_query"
require_relative "solid_queue_tui/data/queues_query"
require_relative "solid_queue_tui/data/processes_query"
require_relative "solid_queue_tui/data/failed_query"

# Actions
require_relative "solid_queue_tui/actions/retry_job"
require_relative "solid_queue_tui/actions/discard_job"
require_relative "solid_queue_tui/actions/dispatch_scheduled_job"
require_relative "solid_queue_tui/actions/discard_scheduled_job"
require_relative "solid_queue_tui/actions/toggle_queue_pause"

# Components
require_relative "solid_queue_tui/components/header"
require_relative "solid_queue_tui/components/job_table"
require_relative "solid_queue_tui/components/help_bar"

# View concerns
require_relative "solid_queue_tui/views/concerns/filterable"

# Views
require_relative "solid_queue_tui/views/dashboard_view"
require_relative "solid_queue_tui/views/queues_view"
require_relative "solid_queue_tui/views/failed_view"
require_relative "solid_queue_tui/views/in_progress_view"
require_relative "solid_queue_tui/views/blocked_view"
require_relative "solid_queue_tui/views/scheduled_view"
require_relative "solid_queue_tui/views/finished_view"
require_relative "solid_queue_tui/views/processes_view"
require_relative "solid_queue_tui/views/job_detail_view"

# Dev tools
require_relative "solid_queue_tui/dev_reloader"

# Application
require_relative "solid_queue_tui/application"
require_relative "solid_queue_tui/cli"

module SolidQueueTui
  @refresh_interval = 200

  class << self
    attr_accessor :refresh_interval
  end
end

require_relative "solid_queue_tui/railtie" if defined?(Rails::Railtie)
