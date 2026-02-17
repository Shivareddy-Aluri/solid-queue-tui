# frozen_string_literal: true

module SolidQueueTui
  module Views
    class BlockedView
      PAGE_SIZE = 100
      LOAD_THRESHOLD = 10

      def initialize(tui)
        @tui = tui
        @table_state = RatatuiRuby::TableState.new(nil)
        @table_state.select(0)
        @selected_row = 0
        @jobs = []
        @total_count = nil
        @all_loaded = false
      end

      def update(jobs:)
        @jobs = jobs
        @all_loaded = jobs.size < PAGE_SIZE
        @selected_row = @selected_row.clamp(0, [@jobs.size - 1, 0].max)
        @table_state.select(@selected_row)
      end

      def append(jobs:)
        @jobs.concat(jobs)
        @all_loaded = jobs.size < PAGE_SIZE
      end

      def total_count=(count)
        @total_count = count
      end

      def current_offset
        @jobs.size
      end

      def reset_pagination!
        @jobs = []
        @total_count = nil
        @all_loaded = false
        @selected_row = 0
        @table_state.select(0)
      end

      def render(frame, area)
        columns = [
          { key: :id,              label: "ID",              width: 8 },
          { key: :queue_name,      label: "QUEUE",            width: 14 },
          { key: :class_name,      label: "CLASS",            width: :fill },
          { key: :priority,        label: "PRI",              width: 5 },
          { key: :concurrency_key, label: "CONCURRENCY KEY",  width: :fill },
          { key: :expires_at,      label: "EXPIRES AT",       width: 20 },
          { key: :blocked_since,   label: "BLOCKED SINCE",    width: 14 }
        ]

        rows = @jobs.map do |job|
          {
            id: job.id,
            queue_name: job.queue_name,
            class_name: job.class_name,
            priority: job.priority,
            concurrency_key: job.concurrency_key || "n/a",
            expires_at: format_time(job.expires_at),
            blocked_since: time_ago(job.created_at)
          }
        end

        table = Components::JobTable.new(
          @tui,
          title: "Blocked",
          columns: columns,
          rows: rows,
          selected_row: @selected_row,
          total_count: @total_count,
          empty_message: "No blocked jobs"
        )

        table.render(frame, area, @table_state)
      end

      def handle_input(event)
        case event
        in { type: :key, code: "j" } | { type: :key, code: "up" }
          move_selection(-1)
        in { type: :key, code: "k" } | { type: :key, code: "down" }
          result = move_selection(1)
          return :load_more if result == :load_more
          nil
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

      def breadcrumb = "blocked"

      private

      def needs_more?
        !@all_loaded && @selected_row >= @jobs.size - LOAD_THRESHOLD
      end

      def move_selection(delta)
        return if @jobs.empty?
        @selected_row = (@selected_row + delta).clamp(0, @jobs.size - 1)
        @table_state.select(@selected_row)
        :load_more if needs_more?
      end

      def jump_to_top
        @selected_row = 0
        @table_state.select(0)
      end

      def jump_to_bottom
        return if @jobs.empty?
        @selected_row = @jobs.size - 1
        @table_state.select(@selected_row)
        return :load_more if needs_more?
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
