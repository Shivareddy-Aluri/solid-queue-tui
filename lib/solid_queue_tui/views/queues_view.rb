# frozen_string_literal: true

module SolidQueueTui
  module Views
    class QueuesView
      include Confirmable

      def initialize(tui)
        @tui = tui
        @table_state = RatatuiRuby::TableState.new(nil)
        @table_state.select(0)
        @selected_row = 0
        @queues = []
        init_confirm
      end

      def update(queues:)
        @queues = queues
        @selected_row = @selected_row.clamp(0, [@queues.size - 1, 0].max)
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
        return nil if @queues.empty? || @selected_row >= @queues.size
        @queues[@selected_row]
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

      def confirm_message
        queue = selected_item
        if @confirm_action == :pause
          "Pause queue '#{queue&.name}'? Workers will stop picking up jobs from this queue. [y/n]"
        else
          "Resume queue '#{queue&.name}'? [y/n]"
        end
      end

      def execute_confirm_action(action)
        queue = selected_item
        return nil unless queue
        Actions::ToggleQueuePause.call(queue.name)
        :refresh
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
    end
  end
end
