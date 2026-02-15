# frozen_string_literal: true

module SolidQueueTui
  module Views
    class FinishedView
      def initialize(tui)
        @tui = tui
        @table_state = RatatuiRuby::TableState.new(nil)
        @table_state.select(0)
        @selected_row = 0
        @jobs = []
        @filter = nil
        @filter_mode = false
        @filter_input = ""
      end

      def update(jobs:)
        @jobs = jobs
        @selected_row = @selected_row.clamp(0, [@jobs.size - 1, 0].max)
        @table_state.select(@selected_row)
      end

      def render(frame, area)
        if @filter_mode
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
        if @filter_mode
          handle_filter_input(event)
        else
          handle_normal_input(event)
        end
      end

      def selected_item
        return nil if @jobs.empty? || @selected_row >= @jobs.size
        @jobs[@selected_row]
      end

      def filter = @filter

      def bindings
        if @filter_mode
          [
            { key: "Enter", action: "Apply" },
            { key: "Esc", action: "Cancel" }
          ]
        else
          [
            { key: "j/k", action: "Navigate" },
            { key: "Enter", action: "Detail" },
            { key: "/", action: "Filter" },
            { key: "Esc", action: "Clear Filter" },
            { key: "G/g", action: "Bottom/Top" }
          ]
        end
      end

      def capturing_input?
        @filter_mode
      end

      def breadcrumb
        @filter ? "finished:#{@filter}" : "finished"
      end

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
        in { type: :key, code: "/" }
          @filter_mode = true
          @filter_input = @filter || ""
        in { type: :key, code: "esc" }
          @filter = nil
          @filter_input = ""
          :refresh
        else
          nil
        end
      end

      def handle_filter_input(event)
        case event
        in { type: :key, code: "enter" }
          @filter = @filter_input.empty? ? nil : @filter_input
          @filter_mode = false
          @selected_row = 0
          @table_state.select(0)
          :refresh
        in { type: :key, code: "esc" }
          @filter_mode = false
          @filter_input = @filter || ""
          nil
        in { type: :key, code: "backspace" }
          @filter_input = @filter_input[0...-1]
          nil
        in { type: :key, code: /\A.\z/ => char }
          @filter_input += char
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
          { key: :id,          label: "ID",          width: 8 },
          { key: :queue_name,  label: "QUEUE",        width: 14 },
          { key: :class_name,  label: "CLASS",        width: :fill },
          { key: :priority,    label: "PRI",          width: 5 },
          { key: :finished_at, label: "FINISHED AT",  width: 20 },
          { key: :duration,    label: "DURATION",     width: 12 }
        ]

        rows = @jobs.map do |job|
          {
            id: job.id,
            queue_name: job.queue_name,
            class_name: job.class_name,
            priority: job.priority,
            finished_at: format_time(job.finished_at),
            duration: format_duration(job.created_at, job.finished_at)
          }
        end

        title = @filter ? "Finished (filter: #{@filter})" : "Finished"

        table = Components::JobTable.new(
          @tui,
          title: title,
          columns: columns,
          rows: rows,
          selected_row: @selected_row,
          empty_message: @filter ? "No finished jobs matching '#{@filter}'" : "No finished jobs"
        )

        table.render(frame, area, @table_state)
      end

      def render_filter_input(frame, area)
        frame.render_widget(
          @tui.paragraph(
            text: @filter_input + "\u2588",
            style: @tui.style(fg: :white),
            block: @tui.block(
              title: " Filter by class name ",
              title_style: @tui.style(fg: :yellow),
              borders: [:all],
              border_type: :rounded,
              border_style: @tui.style(fg: :cyan)
            )
          ),
          area
        )
      end

      def format_time(time)
        return "n/a" unless time
        time.strftime("%Y-%m-%d %H:%M:%S")
      end

      def format_duration(created, finished)
        return "n/a" unless created && finished
        seconds = (finished - created).to_i
        if seconds < 1
          "<1s"
        elsif seconds < 60
          "#{seconds}s"
        elsif seconds < 3600
          "#{seconds / 60}m #{seconds % 60}s"
        else
          "#{seconds / 3600}h #{(seconds % 3600) / 60}m"
        end
      end
    end
  end
end
