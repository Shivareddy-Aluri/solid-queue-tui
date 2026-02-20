# frozen_string_literal: true

module SolidQueueTui
  module Views
    module Filterable
      FILTER_FIELDS = [
        { key: :class_name, label: "Class" },
        { key: :queue, label: "Queue" }
      ].freeze

      def init_filter
        @filters = {}
        @filter_mode = false
        @filter_inputs = {}
        @active_field = 0
      end

      def filters = @filters
      def filter_mode? = @filter_mode

      def handle_filter_input(event)
        case event
        in { type: :key, code: "enter" }
          @filters = @filter_inputs.reject { |_, v| v.nil? || v.empty? }
          @filter_mode = false
          @selected_row = 0
          @table_state.select(0)
          :refresh
        in { type: :key, code: "esc" }
          @filter_mode = false
          @filter_inputs = @filters.dup
          nil
        in { type: :key, code: "tab" }
          @active_field = (@active_field + 1) % FILTER_FIELDS.size
          nil
        in { type: :key, code: "back_tab" }
          @active_field = (@active_field - 1) % FILTER_FIELDS.size
          nil
        in { type: :key, code: "backspace" }
          field_key = FILTER_FIELDS[@active_field][:key]
          current = @filter_inputs[field_key] || ""
          @filter_inputs[field_key] = current[0...-1]
          nil
        in { type: :key, code: /\A.\z/ => char }
          field_key = FILTER_FIELDS[@active_field][:key]
          @filter_inputs[field_key] = (@filter_inputs[field_key] || "") + char
          nil
        else
          nil
        end
      end

      def enter_filter_mode
        @filter_mode = true
        @filter_inputs = @filters.dup
        @active_field = 0
      end

      def clear_filter
        @filters = {}
        @filter_inputs = {}
        :refresh
      end

      def render_filter_input(frame, area)
        spans = []

        FILTER_FIELDS.each_with_index do |field, idx|
          active = idx == @active_field
          value = @filter_inputs[field[:key]] || ""

          spans << @tui.text_span(
            content: " #{field[:label]}: ",
            style: @tui.style(fg: active ? :yellow : :dark_gray, modifiers: active ? [:bold] : [])
          )

          if active
            spans << @tui.text_span(content: value + "\u2588", style: @tui.style(fg: :white))
          else
            spans << @tui.text_span(
              content: value.empty? ? "\u2014" : value,
              style: @tui.style(fg: :dark_gray)
            )
          end

          spans << @tui.text_span(content: "   ", style: @tui.style(fg: :white))
        end

        frame.render_widget(
          @tui.paragraph(
            text: @tui.text_line(spans: spans),
            block: @tui.block(
              title: " Filters ",
              title_style: @tui.style(fg: :yellow),
              titles: [
                { content: " Tab: next field \u2502 Enter: apply \u2502 Esc: cancel ",
                  position: :bottom, alignment: :center }
              ],
              borders: [:all],
              border_type: :rounded,
              border_style: @tui.style(fg: :cyan)
            )
          ),
          area
        )
      end

      def filter_title(base_title)
        return base_title if @filters.empty?

        parts = FILTER_FIELDS.filter_map do |field|
          value = @filters[field[:key]]
          "#{field[:label].downcase}: #{value}" if value && !value.empty?
        end

        "#{base_title} (#{parts.join(', ')})"
      end

      def filter_bindings
        [
          { key: "Tab", action: "Next Field" },
          { key: "Enter", action: "Apply" },
          { key: "Esc", action: "Cancel" }
        ]
      end
    end
  end
end
