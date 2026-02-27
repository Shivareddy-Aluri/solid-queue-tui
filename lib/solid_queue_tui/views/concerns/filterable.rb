# frozen_string_literal: true

module SolidQueueTui
  module Views
    module Filterable
      TEXT_FIELDS = [
        { key: :class_name, label: "Class", type: :text },
        { key: :queue, label: "Queue", type: :text }
      ].freeze

      DATE_FIELD = { key: :date, label: "Date", type: :preset }.freeze

      DATE_PRESETS = [
        { label: "Last 1 hour",   seconds: 3_600 },
        { label: "Last 6 hours",  seconds: 21_600 },
        { label: "Last 24 hours", seconds: 86_400 },
        { label: "Last 7 days",   seconds: 604_800 },
        { label: "Last 30 days",  seconds: 2_592_000 },
        { label: "All time",      seconds: nil }
      ].freeze

      ALL_TIME_INDEX = DATE_PRESETS.size - 1

      # Override in views that need the date preset field
      def filter_fields
        TEXT_FIELDS
      end

      def init_filter
        @filters = {}
        @filter_mode = false
        @filter_inputs = {}
        @active_field = 0
        @date_preset_index = ALL_TIME_INDEX
        @active_date_preset = nil
      end

      def filters = @filters
      def filter_mode? = @filter_mode

      def date_range_start
        return nil unless @active_date_preset

        preset = DATE_PRESETS[@active_date_preset]
        return nil unless preset && preset[:seconds]

        Time.now.utc - preset[:seconds]
      end

      def handle_filter_input(event)
        fields = filter_fields
        case event
        in { type: :key, code: "enter" }
          @filters = @filter_inputs.reject { |_, v| v.nil? || v.empty? }
          if has_date_field?
            preset = DATE_PRESETS[@date_preset_index]
            @active_date_preset = preset[:seconds] ? @date_preset_index : nil
          end
          @filter_mode = false
          @selected_row = 0
          @table_state.select(0)
          :refresh
        in { type: :key, code: "esc" }
          @filter_mode = false
          @filter_inputs = @filters.dup
          @date_preset_index = @active_date_preset || ALL_TIME_INDEX
          nil
        in { type: :key, code: "tab" }
          @active_field = (@active_field + 1) % fields.size
          nil
        in { type: :key, code: "back_tab" }
          @active_field = (@active_field - 1) % fields.size
          nil
        else
          if date_field_active?
            handle_date_field_input(event)
          else
            handle_text_field_input(event)
          end
        end
      end

      def enter_filter_mode
        @filter_mode = true
        @filter_inputs = @filters.dup
        @active_field = 0
        @date_preset_index = @active_date_preset || ALL_TIME_INDEX
      end

      def clear_filter
        had_filters = !@filters.empty? || !!@active_date_preset
        @filters = {}
        @filter_inputs = {}
        @active_date_preset = nil
        had_filters ? :refresh : nil
      end

      def render_filter_input(frame, area)
        spans = []

        filter_fields.each_with_index do |field, idx|
          active = idx == @active_field

          spans << @tui.text_span(
            content: " #{field[:label]}: ",
            style: @tui.style(fg: active ? :yellow : :dark_gray, modifiers: active ? [:bold] : [])
          )

          if field[:type] == :preset
            render_date_field_span(spans, active)
          else
            render_text_field_span(spans, field, active)
          end

          spans << @tui.text_span(content: "   ", style: @tui.style(fg: :white))
        end

        hint = if date_field_active?
                 " Tab: next field \u2502 j/k: cycle \u2502 Enter: apply \u2502 Esc: cancel "
               else
                 " Tab: next field \u2502 Enter: apply \u2502 Esc: cancel "
               end

        frame.render_widget(
          @tui.paragraph(
            text: @tui.text_line(spans: spans),
            block: @tui.block(
              title: " Filters ",
              title_style: @tui.style(fg: :yellow),
              titles: [
                { content: hint, position: :top, alignment: :right }
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
        parts = filter_fields.filter_map do |field|
          next if field[:type] == :preset
          value = @filters[field[:key]]
          "#{field[:label].downcase}: #{value}" if value && !value.empty?
        end

        if @active_date_preset
          parts << DATE_PRESETS[@active_date_preset][:label].downcase
        end

        parts.empty? ? base_title : "#{base_title} (#{parts.join(', ')})"
      end

      def clear_filter_binding
        has_filters = !@filters.empty? || !!@active_date_preset
        has_filters ? { key: "c", action: "Clear Filter" } : nil
      end

      def filter_bindings
        bindings = [
          { key: "Tab", action: "Next Field" },
          { key: "Enter", action: "Apply" },
          { key: "Esc", action: "Cancel" }
        ]
        bindings.unshift({ key: "j/k", action: "Cycle" }) if date_field_active?
        bindings
      end

      private

      def has_date_field?
        filter_fields.any? { |f| f[:type] == :preset }
      end

      def date_field_active?
        @filter_mode && filter_fields[@active_field]&.[](:type) == :preset
      end

      def handle_date_field_input(event)
        case event
        in { type: :key, code: "j" } | { type: :key, code: "down" }
          @date_preset_index = (@date_preset_index + 1) % DATE_PRESETS.size
          nil
        in { type: :key, code: "k" } | { type: :key, code: "up" }
          @date_preset_index = (@date_preset_index - 1) % DATE_PRESETS.size
          nil
        else
          nil
        end
      end

      def handle_text_field_input(event)
        fields = filter_fields
        case event
        in { type: :key, code: "backspace" }
          field_key = fields[@active_field][:key]
          current = @filter_inputs[field_key] || ""
          @filter_inputs[field_key] = current[0...-1]
          nil
        in { type: :key, code: /\A.\z/ => char }
          field_key = fields[@active_field][:key]
          @filter_inputs[field_key] = (@filter_inputs[field_key] || "") + char
          nil
        else
          nil
        end
      end

      def render_text_field_span(spans, field, active)
        value = @filter_inputs[field[:key]] || ""
        if active
          spans << @tui.text_span(content: value + "\u2588", style: @tui.style(fg: :white))
        else
          spans << @tui.text_span(
            content: value.empty? ? "\u2014" : value,
            style: @tui.style(fg: :dark_gray)
          )
        end
      end

      def render_date_field_span(spans, active)
        label = DATE_PRESETS[@date_preset_index][:label]
        if active
          spans << @tui.text_span(
            content: label,
            style: @tui.style(fg: :yellow, modifiers: [:bold])
          )
          spans << @tui.text_span(
            content: " \u25B2\u25BC",
            style: @tui.style(fg: :dark_gray)
          )
        else
          display = @date_preset_index == ALL_TIME_INDEX ? "\u2014" : DATE_PRESETS[@date_preset_index][:label]
          spans << @tui.text_span(
            content: display,
            style: @tui.style(fg: :dark_gray)
          )
        end
      end
    end
  end
end
