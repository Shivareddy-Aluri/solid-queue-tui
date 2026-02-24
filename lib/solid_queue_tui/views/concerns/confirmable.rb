# frozen_string_literal: true

module SolidQueueTui
  module Views
    module Confirmable
      def init_confirm
        @confirm_action = nil
      end

      def confirm_mode? = !!@confirm_action

      def confirm_bindings
        [{ key: "y", action: "Confirm" }, { key: "n/Esc", action: "Cancel" }]
      end

      def handle_confirm_input(event)
        case event
        in { type: :key, code: "y" }
          action = @confirm_action
          @confirm_action = nil
          execute_confirm_action(action)
        in { type: :key, code: "n" } | { type: :key, code: "esc" }
          @confirm_action = nil
          nil
        else
          nil
        end
      end

      def render_confirm_popup(frame, area)
        popup_area = area.centered(
          @tui.constraint_percentage(50),
          @tui.constraint_length(5)
        )
        frame.render_widget(@tui.clear(), popup_area)
        frame.render_widget(
          @tui.paragraph(
            text: " #{confirm_message}",
            style: @tui.style(fg: :yellow, modifiers: [:bold]),
            block: @tui.block(
              title: " Confirm ",
              title_style: @tui.style(fg: :red, modifiers: [:bold]),
              borders: [:all],
              border_type: :rounded,
              border_style: @tui.style(fg: :red)
            )
          ),
          popup_area
        )
      end
    end
  end
end
