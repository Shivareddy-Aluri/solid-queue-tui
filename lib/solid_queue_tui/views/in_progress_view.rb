# frozen_string_literal: true

module SolidQueueTui
  module Views
    class InProgressView
      include Filterable
      include Paginatable

      def initialize(tui)
        @tui = tui
        init_pagination
        init_filter
      end

      def update(jobs:)
        update_items(jobs)
      end

      def append(jobs:)
        append_items(jobs)
      end

      def render(frame, area)
        if filter_mode?
          filter_area, content_area = @tui.layout_split(
            area,
            direction: :vertical,
            constraints: [
              @tui.constraint_length(3),
              @tui.constraint_fill(1)
            ]
          )
          render_filter_input(frame, filter_area)
          render_table(frame, content_area)
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
        @filters.empty? ? "in-progress" : "in-progress:filtered"
      end

      private

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

      def render_table(frame, area)
        columns = [
          { key: :id,         label: "ID",        width: 8 },
          { key: :queue_name, label: "QUEUE",      width: 14 },
          { key: :class_name, label: "CLASS",      width: :fill },
          { key: :priority,   label: "PRI",        width: 5 },
          { key: :worker_id,  label: "WORKER",     width: 8 },
          { key: :started_at, label: "STARTED",    width: 12 }
        ]

        rows = items.map do |job|
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
          empty_message: @filters.empty? ? "No jobs currently in progress" : "No in-progress jobs matching filters"
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
