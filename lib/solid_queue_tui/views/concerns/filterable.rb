# frozen_string_literal: true

module SolidQueueTui
  module Views
    module Filterable
      def init_filter
        @filter = nil
        @filter_mode = false
        @filter_input = ""
      end

      def filter = @filter
      def filter_mode? = @filter_mode

      # Call from handle_input when @filter_mode is true.
      # Returns :refresh on apply, nil otherwise.
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

      # Call from handle_normal_input when "/" is pressed.
      def enter_filter_mode
        @filter_mode = true
        @filter_input = @filter || ""
      end

      # Call from handle_normal_input when "esc" is pressed.
      # Returns :refresh.
      def clear_filter
        @filter = nil
        @filter_input = ""
        :refresh
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

      def filter_title(base_title)
        @filter ? "#{base_title} (filter: #{@filter})" : base_title
      end

      def filter_bindings
        [
          { key: "Enter", action: "Apply" },
          { key: "Esc", action: "Cancel" }
        ]
      end
    end
  end
end
