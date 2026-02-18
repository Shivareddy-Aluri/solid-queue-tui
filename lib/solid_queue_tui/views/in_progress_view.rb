# frozen_string_literal: true

module SolidQueueTui
  module Views
    class InProgressView
      include Filterable

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
        init_filter
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
        if filter_mode?
          content_area, filter_area = @tui.layout_split(
            area,
            direction: :vertical,
            constraints: [
              @tui.constraint_fill(1),
              @tui.constraint_length(3)
            ]
          )
          render_table(frame, content_area)
          render_filter_input(frame, filter_area)
        else
          render_table(frame, area)
        end
      end

      def handle_input(event)
        if filter_mode?
          handle_filter_input(event)
        else
          handle_normal_input(event)
        end
      end

      def selected_item
        return nil if @jobs.empty? || @selected_row >= @jobs.size
        @jobs[@selected_row]
      end

      def bindings
        if filter_mode?
          filter_bindings
        else
          [
            { key: "j/k", action: "Navigate" },
            { key: "Enter", action: "Detail" },
            { key: "/", action: "Filter" },
            { key: "G/g", action: "Bottom/Top" }
          ]
        end
      end

      def capturing_input?
        filter_mode?
      end

      def breadcrumb
        @filter ? "in-progress:#{@filter}" : "in-progress"
      end

      private

      def needs_more?
        !@all_loaded && @selected_row >= @jobs.size - LOAD_THRESHOLD
      end

      def handle_normal_input(event)
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
        in { type: :key, code: "/" }
          enter_filter_mode
          nil
        in { type: :key, code: "esc" }
          clear_filter
        else
          nil
        end
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

      def render_table(frame, area)
        columns = [
          { key: :id,         label: "ID",        width: 8 },
          { key: :queue_name, label: "QUEUE",      width: 14 },
          { key: :class_name, label: "CLASS",      width: :fill },
          { key: :priority,   label: "PRI",        width: 5 },
          { key: :worker_id,  label: "WORKER",     width: 8 },
          { key: :started_at, label: "STARTED",    width: 12 }
        ]

        rows = @jobs.map do |job|
          {
            id: job.id,
            queue_name: job.queue_name,
            class_name: job.class_name,
            priority: job.priority,
            worker_id: job.worker_id || "n/a",
            started_at: time_ago(job.started_at)
          }
        end

        table = Components::JobTable.new(
          @tui,
          title: filter_title("In Progress"),
          columns: columns,
          rows: rows,
          selected_row: @selected_row,
          total_count: @total_count,
          empty_message: @filter ? "No in-progress jobs matching '#{@filter}'" : "No jobs currently in progress"
        )

        table.render(frame, area, @table_state)
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
