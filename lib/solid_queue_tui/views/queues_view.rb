# frozen_string_literal: true

module SolidQueueTui
  module Views
    class QueuesView
      def initialize(tui)
        @tui = tui
        @table_state = RatatuiRuby::TableState.new(nil)
        @table_state.select(0)
        @selected_row = 0
        @queues = []
        @confirm_action = nil
      end

      def update(queues:)
        @queues = queues
        @selected_row = @selected_row.clamp(0, [@queues.size - 1, 0].max)
        @table_state.select(@selected_row)
      end

      def render(frame, area)
        if @confirm_action
          render_table(frame, area)
          popup_area = area.centered(
            @tui.constraint_percentage(50),
            @tui.constraint_length(5)
          )
          frame.render_widget(@tui.clear(), popup_area)
          render_confirm(frame, popup_area)
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
        return nil if @queues.empty? || @selected_row >= @queues.size
        @queues[@selected_row]
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
            { key: "p", action: "Pause/Resume" },
            { key: "G/g", action: "Bottom/Top" }
          ]
        end
      end

      def breadcrumb = "queues"

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
        in { type: :key, code: "p" }
          queue = selected_item
          if queue
            @confirm_action = queue.paused ? :resume : :pause
          end
          nil
        else
          nil
        end
      end

      def handle_confirm_input(event)
        case event
        in { type: :key, code: "y" }
          @confirm_action = nil
          queue = selected_item
          return nil unless queue
          Actions::ToggleQueuePause.call(queue.name)
          :refresh
        in { type: :key, code: "n" } | { type: :key, code: "esc" }
          @confirm_action = nil
          nil
        else
          nil
        end
      end

      def move_selection(delta)
        return if @queues.empty?
        @selected_row = (@selected_row + delta).clamp(0, @queues.size - 1)
        @table_state.select(@selected_row)
      end

      def jump_to_top
        @selected_row = 0
        @table_state.select(0)
      end

      def jump_to_bottom
        return if @queues.empty?
        @selected_row = @queues.size - 1
        @table_state.select(@selected_row)
      end

      def render_table(frame, area)
        columns = [
          { key: :name,   label: "QUEUE",   width: :fill },
          { key: :size,   label: "SIZE",    width: 10 },
          { key: :status, label: "STATUS",  width: 10, color_by: :status }
        ]

        rows = @queues.map do |q|
          {
            name: q.name,
            size: q.size,
            status: q.paused ? "paused" : "active"
          }
        end

        table = Components::JobTable.new(
          @tui,
          title: "Queues",
          columns: columns,
          rows: rows,
          selected_row: @selected_row,
          empty_message: "No queues found"
        )

        table.render(frame, area, @table_state)
      end

      def render_confirm(frame, area)
        queue = selected_item
        message = if @confirm_action == :pause
                    "Pause queue '#{queue&.name}'? Workers will stop picking up jobs from this queue. [y/n]"
                  else
                    "Resume queue '#{queue&.name}'? [y/n]"
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
    end
  end
end
