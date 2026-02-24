# frozen_string_literal: true

module SolidQueueTui
  module Views
    class ProcessesView
      include FormattingHelpers

      KIND_COLORS = {
        "Worker" => :green,
        "Dispatcher" => :yellow,
        "Scheduler" => :blue
      }.freeze

      def initialize(tui)
        @tui = tui
        @table_state = RatatuiRuby::TableState.new(nil)
        @table_state.select(0)
        @selected_row = 0
        @processes = []
      end

      def update(processes:)
        @processes = processes
        @selected_row = @selected_row.clamp(0, [@processes.size - 1, 0].max)
        @table_state.select(@selected_row)
      end

      def render(frame, area)
        columns = [
          { key: :id,        label: "ID",        width: 6 },
          { key: :kind,      label: "KIND",       width: 12 },
          { key: :hostname,  label: "HOSTNAME",   width: :fill },
          { key: :pid,       label: "PID",        width: 8 },
          { key: :name,      label: "NAME",       width: :fill },
          { key: :queues,    label: "QUEUES",     width: :fill },
          { key: :heartbeat, label: "HEARTBEAT",  width: 12 },
          { key: :uptime,    label: "UPTIME",     width: 10 },
          { key: :status,    label: "STATUS",     width: 8 }
        ]

        rows = @processes.map do |proc|
          alive = proc.alive?

          {
            id: proc.id,
            kind: proc.kind,
            hostname: proc.hostname || "n/a",
            pid: proc.pid,
            name: proc.name || "n/a",
            queues: Array(proc.queues).join(", "),
            heartbeat: time_ago(proc.last_heartbeat_at),
            uptime: format_duration(proc.uptime),
            status: alive ? "alive" : "dead"
          }
        end

        table = Components::JobTable.new(
          @tui,
          title: "Processes",
          columns: columns,
          rows: rows,
          selected_row: @selected_row,
          empty_message: "No active processes — is Solid Queue running?"
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
        return nil if @processes.empty? || @selected_row >= @processes.size
        @processes[@selected_row]
      end

      def bindings
        [
          { key: "j/k", action: "Navigate" },
          { key: "Enter", action: "Detail" },
          { key: "G/g", action: "Bottom/Top" }
        ]
      end

      def breadcrumb = "processes"

      private

      def move_selection(delta)
        return if @processes.empty?
        @selected_row = (@selected_row + delta).clamp(0, @processes.size - 1)
        @table_state.select(@selected_row)
      end

      def jump_to_top
        @selected_row = 0
        @table_state.select(0)
      end

      def jump_to_bottom
        return if @processes.empty?
        @selected_row = @processes.size - 1
        @table_state.select(@selected_row)
      end

    end
  end
end
