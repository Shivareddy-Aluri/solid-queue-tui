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
      end

      def update(queues:)
        @queues = queues
        @selected_row = @selected_row.clamp(0, [@queues.size - 1, 0].max)
        @table_state.select(@selected_row)
      end

      def render(frame, area)
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

      def handle_input(event)
        case event
        in { type: :key, code: "j" } | { type: :key, code: "up" }
          move_selection(-1)
        in { type: :key, code: "k" } | { type: :key, code: "down" }
          move_selection(1)
        in { type: :key, code: "g" }
          jump_to_top
        in { type: :key, code: "G" }
          jump_to_bottom
        else
          nil
        end
      end

      def selected_item
        return nil if @queues.empty? || @selected_row >= @queues.size
        @queues[@selected_row]
      end

      def bindings
        [
          { key: "j/k", action: "Navigate" },
          { key: "G/g", action: "Bottom/Top" }
        ]
      end

      def breadcrumb = "queues"

      private

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
    end
  end
end
