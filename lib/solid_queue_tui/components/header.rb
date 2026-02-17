# frozen_string_literal: true

module SolidQueueTui
  module Components
    class Header
      LOGO = [
        " ____        _ _     _    ___                         ",
        "/ ___|  ___ | (_) __| |  / _ \\  _   _  ___ _   _  ___",
        "\\___ \\ / _ \\| | |/ _` | | | | || | | |/ _ \\ | | |/ _ \\",
        " ___) | (_) | | | (_| | | |_| || |_| |  __/ |_| |  __/",
        "|____/ \\___/|_|_|\\__,_|  \\__\\_\\ \\__,_|\\___|\\__,_|\\___|"
      ].freeze

      VIEWS = [
        { key: "1", label: "Dashboard" },
        { key: "2", label: "Queues" },
        { key: "3", label: "Failed" },
        { key: "4", label: "In Progress" },
        { key: "5", label: "Blocked" },
        { key: "6", label: "Scheduled" },
        { key: "7", label: "Finished" },
        { key: "8", label: "Workers" }
      ].freeze

      def initialize(tui, current_view:)
        @tui = tui
        @current_view = current_view
      end

      def render(frame, area)
        left_area, right_area = @tui.layout_split(
          area,
          direction: :horizontal,
          constraints: [
            @tui.constraint_percentage(50),
            @tui.constraint_percentage(50)
          ]
        )

        render_info(frame, left_area)
        render_nav(frame, right_area)
      end

      private

      def render_info(frame, area)
        lines = LOGO.map do |logo_line|
          @tui.text_line(spans: [
            @tui.text_span(content: " #{logo_line}", style: @tui.style(fg: :red, modifiers: [:bold]))
          ])
        end

        lines << @tui.text_line(spans: [
          @tui.text_span(content: " v#{VERSION}", style: @tui.style(fg: :dark_gray))
        ])

        frame.render_widget(
          @tui.paragraph(text: lines),
          area
        )
      end

      def render_nav(frame, area)
        spans = [
          @tui.text_span(content: " ", style: @tui.style(fg: :white))
        ]

        VIEWS.each_with_index do |view, idx|
          active = idx == @current_view

          spans << @tui.text_span(
            content: "<#{view[:key]}>",
            style: @tui.style(fg: :cyan, modifiers: active ? [:bold] : [])
          )
          spans << @tui.text_span(
            content: " #{view[:label]}",
            style: @tui.style(
              fg: active ? :yellow : :dark_gray,
              modifiers: active ? [:bold, :underlined] : []
            )
          )
          spans << @tui.text_span(content: "  ", style: @tui.style(fg: :white))
        end

        lines = [
          @tui.text_line(spans: spans, alignment: :right),
          @tui.text_line(spans: [
            @tui.text_span(content: "<?>", style: @tui.style(fg: :cyan)),
            @tui.text_span(content: " Help  ", style: @tui.style(fg: :dark_gray)),
            @tui.text_span(content: "<q>", style: @tui.style(fg: :cyan)),
            @tui.text_span(content: " Quit  ", style: @tui.style(fg: :dark_gray)),
            @tui.text_span(content: "<r>", style: @tui.style(fg: :cyan)),
            @tui.text_span(content: " Refresh", style: @tui.style(fg: :dark_gray))
          ], alignment: :right)
        ]

        frame.render_widget(
          @tui.paragraph(text: lines),
          area
        )
      end

    end
  end
end
