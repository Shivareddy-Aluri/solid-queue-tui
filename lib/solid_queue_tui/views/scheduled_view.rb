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
        @confirm_action = nil
      end

      def update(jobs:)
        @jobs = jobs
        @selected_row = @selected_row.clamp(0, [@jobs.size - 1, 0].max)
        @table_state.select(@selected_row)
      end

      def render(frame, area)
        if @confirm_action
          content_area, confirm_area = @tui.layout_split(
            area,
            direction: :vertical,
            constraints: [
              @tui.constraint_fill(1),
              @tui.constraint_length(3)
            ]
          )
          render_table(frame, content_area)
          render_confirm(frame, confirm_area)
        else
          render_table(frame, area)
        end
      end

      def handle_input(event)
        if @confirm_action
          handle_confirm_input(event)
        else
          handle_normal_input(event)
        end
      end

      def selected_item
        return nil if @jobs.empty? || @selected_row >= @jobs.size
        @jobs[@selected_row]
      end

      def capturing_input?
        !!@confirm_action
      end

      def bindings
        if @confirm_action
          [
            { key: "y", action: "Confirm" },
            { key: "n/Esc", action: "Cancel" }
          ]
        else
          [
            { key: "j/k", action: "Navigate" },
            { key: "Enter", action: "Detail" },
            { key: "N", action: "Run Now" },
            { key: "D", action: "Discard" },
            { key: "G/g", action: "Bottom/Top" }
          ]
        end
      end

      def breadcrumb = "scheduled"

      private

      def handle_normal_input(event)
        case event
        in { type: :key, code: "j" } | { type: :key, code: "up" }
          move_selection(-1)
        in { type: :key, code: "k" } | { type: :key, code: "down" }
          move_selection(1)
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
        else
          nil
        end
      end

      def handle_confirm_input(event)
        case event
        in { type: :key, code: "y" }
          action = @confirm_action
          @confirm_action = nil
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
        in { type: :key, code: "n" } | { type: :key, code: "esc" }
          @confirm_action = nil
          nil
        else
          nil
        end
      end

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

      def render_table(frame, area)
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

      def render_confirm(frame, area)
        message = case @confirm_action
                  when :run_now
                    job = selected_item
                    "Run job ##{job&.id} (#{job&.class_name}) now? [y/n]"
                  when :discard
                    job = selected_item
                    "Discard job ##{job&.id} (#{job&.class_name})? This cannot be undone. [y/n]"
                  end

        frame.render_widget(
          @tui.paragraph(
            text: " #{message}",
            style: @tui.style(fg: :yellow, modifiers: [:bold]),
            block: @tui.block(
              title: " Confirm ",
              title_style: @tui.style(fg: :red, modifiers: [:bold]),
              borders: [:all],
              border_type: :rounded,
              border_style: @tui.style(fg: :red)
            )
          ),
          area
        )
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
