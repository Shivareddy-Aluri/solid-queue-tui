# frozen_string_literal: true

require "json"
require "time"

require_relative "solid_queue_tui/version"
require_relative "solid_queue_tui/connection"

# Data layer
require_relative "solid_queue_tui/data/stats"
require_relative "solid_queue_tui/data/jobs_query"
require_relative "solid_queue_tui/data/queues_query"
require_relative "solid_queue_tui/data/processes_query"
require_relative "solid_queue_tui/data/failed_query"

# Actions
require_relative "solid_queue_tui/actions/retry_job"
require_relative "solid_queue_tui/actions/discard_job"

# Components
require_relative "solid_queue_tui/components/header"
require_relative "solid_queue_tui/components/stats_bar"
require_relative "solid_queue_tui/components/job_table"
require_relative "solid_queue_tui/components/help_bar"

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
end
