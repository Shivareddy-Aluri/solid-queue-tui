# frozen_string_literal: true

module SolidQueueTui
  module Views
    class RecurringTasksView
      def initialize(tui)
        @tui = tui
        @table_state = RatatuiRuby::TableState.new(nil)
        @table_state.select(0)
        @selected_row = 0
        @tasks = []
        @confirm_action = nil
      end

      def update(tasks:)
        @tasks = tasks
        @selected_row = @selected_row.clamp(0, [@tasks.size - 1, 0].max)
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
        return nil if @tasks.empty? || @selected_row >= @tasks.size
        @tasks[@selected_row]
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

      def handle_confirm_input(event)
        case event
        in { type: :key, code: "y" }
          @confirm_action = nil
          task = selected_item
          return nil unless task
          Actions::EnqueueRecurringTask.call(task.key)
          :refresh
        in { type: :key, code: "n" } | { type: :key, code: "esc" }
          @confirm_action = nil
          nil
        else
          nil
        end
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

      def render_confirm(frame, area)
        task = selected_item
        message = "Run '#{task&.key}' (#{task&.class_name || task&.command}) now? [y/n]"

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

      def time_ago(time)
        return "Never" unless time
        seconds = (Time.now.utc - time).to_i
        return "just now" if seconds < 5
        "#{humanize_duration(seconds)} ago"
      end

      def time_until(time)
        return "n/a" unless time
        seconds = (time - Time.now.utc).to_i
        return "now" if seconds <= 0
        "in #{humanize_duration(seconds)}"
      end

      def humanize_duration(seconds)
        case seconds.abs
        when 0..59       then "#{seconds.abs}s"
        when 60..3599    then "#{seconds.abs / 60}m"
        when 3600..86399 then "#{seconds.abs / 3600}h"
        else "#{seconds.abs / 86400}d"
        end
      end
    end
  end
end
