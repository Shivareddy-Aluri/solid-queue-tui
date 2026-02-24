# frozen_string_literal: true

module SolidQueueTui
  module Views
    class RecurringTasksView
      include Confirmable
      include FormattingHelpers

      def initialize(tui)
        @tui = tui
        @table_state = RatatuiRuby::TableState.new(nil)
        @table_state.select(0)
        @selected_row = 0
        @tasks = []
        init_confirm
      end

      def update(tasks:)
        @tasks = tasks
        @selected_row = @selected_row.clamp(0, [@tasks.size - 1, 0].max)
        @table_state.select(@selected_row)
      end

      def render(frame, area)
        if confirm_mode?
          render_table(frame, area)
          render_confirm_popup(frame, area)
        else
          render_table(frame, area)
        end
      end

      def handle_input(event)
        if confirm_mode?
          handle_confirm_input(event)
        else
          handle_normal_input(event)
        end
      end

      def selected_item
        return nil if @tasks.empty? || @selected_row >= @tasks.size
        @tasks[@selected_row]
      end

      def capturing_input?
        confirm_mode?
      end

      def bindings
        if confirm_mode?
          confirm_bindings
        else
          [
            { key: "j/k", action: "Navigate" },
            { key: "N", action: "Run Now" },
            { key: "G/g", action: "Bottom/Top" }
          ]
        end
      end

      def breadcrumb = "recurring"

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
        else
          nil
        end
      end

      def confirm_message
        task = selected_item
        "Run '#{task&.key}' (#{task&.class_name || task&.command}) now? [y/n]"
      end

      def execute_confirm_action(action)
        task = selected_item
        return nil unless task
        Actions::EnqueueRecurringTask.call(task.key)
        :refresh
      end

      def move_selection(delta)
        return if @tasks.empty?
        @selected_row = (@selected_row + delta).clamp(0, @tasks.size - 1)
        @table_state.select(@selected_row)
      end

      def jump_to_top
        @selected_row = 0
        @table_state.select(0)
      end

      def jump_to_bottom
        return if @tasks.empty?
        @selected_row = @tasks.size - 1
        @table_state.select(@selected_row)
      end

      def render_table(frame, area)
        columns = [
          { key: :key,              label: "KEY",           width: :fill },
          { key: :class_name,       label: "CLASS",         width: :fill },
          { key: :schedule,         label: "SCHEDULE",      width: 20 },
          { key: :queue_name,       label: "QUEUE",         width: 14 },
          { key: :last_enqueued_at, label: "LAST ENQUEUED", width: 20 },
          { key: :next_time,        label: "NEXT",          width: 20 }
        ]

        rows = @tasks.map do |task|
          {
            key: task.key,
            class_name: task.class_name || task.command || "n/a",
            schedule: task.schedule,
            queue_name: task.queue_name || "default",
            last_enqueued_at: time_ago(task.last_enqueued_at),
            next_time: time_until(task.next_time)
          }
        end

        table = Components::JobTable.new(
          @tui,
          title: "Recurring Tasks",
          columns: columns,
          rows: rows,
          selected_row: @selected_row,
          empty_message: "No recurring tasks configured"
        )

        table.render(frame, area, @table_state)
      end

      # Override: returns "Never" for nil and "just now" for very recent
      def time_ago(time)
        return "Never" unless time
        seconds = (Time.now.utc - time).to_i
        return "just now" if seconds < 5
        "#{humanize_duration(seconds)} ago"
      end
    end
  end
end
