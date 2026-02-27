# frozen_string_literal: true

module SolidQueueTui
  module Views
    class ScheduledView
      include Filterable
      include Confirmable
      include Paginatable
      include FormattingHelpers

      def initialize(tui)
        @tui = tui
        init_pagination
        init_confirm
        init_filter
      end

      def update(jobs:)
        update_items(jobs)
      end

      def append(jobs:)
        append_items(jobs)
      end

      def render(frame, area)
        if confirm_mode?
          render_table(frame, area)
          render_confirm_popup(frame, area)
        elsif filter_mode?
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
        if confirm_mode?
          handle_confirm_input(event)
        elsif filter_mode?
          handle_filter_input(event)
        else
          handle_normal_input(event)
        end
      end

      def capturing_input?
        filter_mode? || confirm_mode?
      end

      def bindings
        if confirm_mode?
          confirm_bindings
        elsif filter_mode?
          filter_bindings
        else
          [
            { key: "j/k", action: "Navigate" },
            { key: "Enter", action: "Detail" },
            { key: "/", action: "Filter" },
            clear_filter_binding,
            { key: "N", action: "Run Now" },
            { key: "D", action: "Discard" },
            { key: "G/g", action: "Bottom/Top" }
          ].compact
        end
      end

      def breadcrumb
        @filters.empty? ? "scheduled" : "scheduled:filtered"
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
        in { type: :key, code: "N" }
          @confirm_action = :run_now if selected_item
          nil
        in { type: :key, code: "D" }
          @confirm_action = :discard if selected_item
          nil
        in { type: :key, code: "/" }
          enter_filter_mode
          nil
        in { type: :key, code: "c" }
          clear_filter
        else
          nil
        end
      end

      def confirm_message
        case @confirm_action
        when :run_now
          job = selected_item
          "Run job ##{job&.id} (#{job&.class_name}) now? [y/n]"
        when :discard
          job = selected_item
          "Discard job ##{job&.id} (#{job&.class_name})? This cannot be undone. [y/n]"
        end
      end

      def execute_confirm_action(action)
        case action
        when :run_now
          item = selected_item
          return nil unless item
          Actions::DispatchScheduledJob.call(item.id)
          :refresh
        when :discard
          item = selected_item
          return nil unless item
          Actions::DiscardScheduledJob.call(item.id)
          :refresh
        end
      end

      def render_table(frame, area)
        columns = [
          { key: :id,           label: "ID",          width: 8 },
          { key: :class_name,   label: "JOB CLASS",    width: :fill },
          { key: :queue_name,   label: "QUEUE",        width: 14 },
          { key: :priority,     label: "PRI",          width: 5 },
          { key: :scheduled_at, label: "SCHEDULED AT", width: 20 },
          { key: :status,       label: "STATUS",       width: 10, color_by: :status },
          { key: :created_at,   label: "CREATED",      width: 12 }
        ]

        now = Time.now.utc
        rows = items.map do |job|
          delayed = job.scheduled_at && job.scheduled_at < now
          {
            id: job.id,
            class_name: job.class_name,
            queue_name: job.queue_name,
            priority: job.priority,
            scheduled_at: format_time(job.scheduled_at),
            status: delayed ? "DELAYED" : "pending",
            created_at: time_ago(job.created_at)
          }
        end

        table = Components::JobTable.new(
          @tui,
          title: filter_title("Scheduled Jobs"),
          columns: columns,
          rows: rows,
          selected_row: @selected_row,
          total_count: @total_count,
          empty_message: "No scheduled jobs"
        )

        table.render(frame, area, @table_state)
      end

    end
  end
end
