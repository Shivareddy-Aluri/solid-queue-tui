# frozen_string_literal: true

module SolidQueueTui
  module Components
    class JobTable
      STATUS_COLORS = {
        "ready" => :green,
        "claimed" => :yellow,
        "scheduled" => :blue,
        "failed" => :red,
        "blocked" => :magenta,
        "completed" => :dark_gray,
        "active" => :green,
        "paused" => :red,
        "unknown" => :white
      }.freeze

      def initialize(tui, title:, columns:, rows:, selected_row: nil, empty_message: "No data")
        @tui = tui
        @title = title
        @columns = columns
        @rows = rows
        @selected_row = selected_row
        @empty_message = empty_message
      end

      def render(frame, area, table_state)
        if @rows.empty?
          render_empty(frame, area)
          return
        end

        render_table(frame, area, table_state)
      end

      private

      def title_text
        text = " #{@title} [#{@rows.size}]"
        text += "  #{@selected_row + 1}/#{@rows.size}" if @selected_row && @rows.size > 0
        text + " "
      end

      def render_table(frame, area, table_state)
        widths = @columns.map do |col|
          case col[:width]
          when :fill then @tui.constraint_fill(1)
          when Integer then @tui.constraint_length(col[:width])
          else @tui.constraint_length(12)
          end
        end

        header = @columns.map { |col| col[:label] }

        table = @tui.table(
          rows: build_rows,
          header: header,
          widths: widths,
          selected_row: @selected_row,
          row_highlight_style: @tui.style(fg: :black, bg: :cyan, modifiers: [:bold]),
          highlight_symbol: " > ",
          highlight_spacing: :always,
          column_spacing: 1,
          style: @tui.style(fg: :white),
          block: @tui.block(
            title: title_text,
            title_style: @tui.style(fg: :yellow, modifiers: [:bold]),
            borders: [:all],
            border_type: :rounded,
            border_style: @tui.style(fg: :dark_gray)
          )
        )

        frame.render_stateful_widget(table, area, table_state)
      end

      def build_rows
        @rows.map do |row|
          cells = @columns.map do |col|
            value = row[col[:key]]
            style = cell_style(col, value)

            if style
              @tui.table_cell(content: value.to_s, style: style)
            else
              value.to_s
            end
          end

          @tui.table_row(cells: cells)
        end
      end

      def cell_style(col, value)
        if col[:color_by] == :status
          color = STATUS_COLORS[value.to_s.downcase] || :white
          @tui.style(fg: color, modifiers: [:bold])
        elsif col[:color]
          @tui.style(fg: col[:color])
        end
      end

      def render_empty(frame, area)
        frame.render_widget(
          @tui.paragraph(
            text: @empty_message,
            alignment: :center,
            style: @tui.style(fg: :dark_gray),
            block: @tui.block(
              title: " #{@title} ",
              title_style: @tui.style(fg: :yellow, modifiers: [:bold]),
              borders: [:all],
              border_type: :rounded,
              border_style: @tui.style(fg: :dark_gray)
            )
          ),
          area
        )
      end
    end
  end
end
