# frozen_string_literal: true

module SolidQueueTui
  module Components
    class HelpBar
      DEFAULT_BINDINGS = [
        { key: "q", action: "Quit" },
        { key: "r", action: "Refresh" },
        { key: "Tab", action: "Next View" },
        { key: "j/k", action: "Navigate" },
        { key: "/", action: "Filter" },
        { key: "Esc", action: "Clear" }
      ].freeze

      def initialize(tui, breadcrumb:, bindings: nil, status: nil)
        @tui = tui
        @breadcrumb = breadcrumb
        @bindings = bindings || DEFAULT_BINDINGS
        @status = status
      end

      def render(frame, area)
        left, right = @tui.layout_split(
          area,
          direction: :horizontal,
          constraints: [
            @tui.constraint_percentage(30),
            @tui.constraint_percentage(70)
          ]
        )

        render_breadcrumb(frame, left)
        render_bindings(frame, right)
      end

      private

      def render_breadcrumb(frame, area)
        spans = [
          @tui.text_span(content: " <", style: @tui.style(fg: :dark_gray)),
          @tui.text_span(content: @breadcrumb, style: @tui.style(fg: :yellow, modifiers: [:bold])),
          @tui.text_span(content: ">", style: @tui.style(fg: :dark_gray))
        ]

        if @status
          spans << @tui.text_span(content: "  #{@status}", style: @tui.style(fg: :dark_gray))
        end

        frame.render_widget(
          @tui.paragraph(text: [@tui.text_line(spans: spans)]),
          area
        )
      end

      def render_bindings(frame, area)
        spans = []

        @bindings.each_with_index do |binding, idx|
          spans << @tui.text_span(
            content: binding[:key],
            style: @tui.style(fg: :cyan, modifiers: [:bold])
          )
          spans << @tui.text_span(
            content: ":#{binding[:action]}",
            style: @tui.style(fg: :dark_gray)
          )
          spans << @tui.text_span(content: "  ", style: @tui.style(fg: :white)) if idx < @bindings.size - 1
        end

        frame.render_widget(
          @tui.paragraph(text: [@tui.text_line(spans: spans, alignment: :right)]),
          area
        )
      end
    end
  end
end
