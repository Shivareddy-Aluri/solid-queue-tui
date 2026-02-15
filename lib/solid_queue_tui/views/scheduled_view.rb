# frozen_string_literal: true

module SolidQueueTui
  module Views
    class ScheduledView
      def initialize(tui)
        @tui = tui
        @table_state = RatatuiRuby::TableState.new(nil)
        @table_state.select(0)
        @selected_row = 0
        @jobs = []
      end

      def update(jobs:)
        @jobs = jobs
        @selected_row = @selected_row.clamp(0, [@jobs.size - 1, 0].max)
        @table_state.select(@selected_row)
      end

      def render(frame, area)
        columns = [
          { key: :id,           label: "ID",          width: 8 },
          { key: :class_name,   label: "JOB CLASS",    width: :fill },
          { key: :queue_name,   label: "QUEUE",        width: 14 },
          { key: :priority,     label: "PRI",          width: 5 },
          { key: :scheduled_at, label: "SCHEDULED AT", width: 20 },
          { key: :created_at,   label: "CREATED",      width: 12 }
        ]

        rows = @jobs.map do |job|
          {
            id: job.id,
            class_name: job.class_name,
            queue_name: job.queue_name,
            priority: job.priority,
            scheduled_at: format_time(job.scheduled_at),
            created_at: time_ago(job.created_at)
          }
        end

        table = Components::JobTable.new(
          @tui,
          title: "Scheduled Jobs",
          columns: columns,
          rows: rows,
          selected_row: @selected_row,
          empty_message: "No scheduled jobs"
        )

        table.render(frame, area, @table_state)
      end

      def handle_input(event)
        case event
        in { type: :key, code: "j" } | { type: :key, code: "up" }
          move_selection(-1)
        in { type: :key, code: "k" } | { type: :key, code: "down" }
          move_selection(1)
        in { type: :key, code: "g" }
          jump_to_top
        in { type: :key, code: "G" }
          jump_to_bottom
        else
          nil
        end
      end

      def selected_item
        return nil if @jobs.empty? || @selected_row >= @jobs.size
        @jobs[@selected_row]
      end

      def bindings
        [
          { key: "j/k", action: "Navigate" },
          { key: "Enter", action: "Detail" },
          { key: "G/g", action: "Bottom/Top" }
        ]
      end

      def breadcrumb = "scheduled"

      private

      def move_selection(delta)
        return if @jobs.empty?
        @selected_row = (@selected_row + delta).clamp(0, @jobs.size - 1)
        @table_state.select(@selected_row)
      end

      def jump_to_top
        @selected_row = 0
        @table_state.select(0)
      end

      def jump_to_bottom
        return if @jobs.empty?
        @selected_row = @jobs.size - 1
        @table_state.select(@selected_row)
      end

      def format_time(time)
        return "n/a" unless time
        time.strftime("%Y-%m-%d %H:%M:%S")
      end

      def time_ago(time)
        return "n/a" unless time
        seconds = (Time.now.utc - time).to_i
        case seconds
        when 0..59       then "#{seconds}s ago"
        when 60..3599    then "#{seconds / 60}m ago"
        when 3600..86399 then "#{seconds / 3600}h ago"
        else "#{seconds / 86400}d ago"
        end
      end
    end
  end
end
