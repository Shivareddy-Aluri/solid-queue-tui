# frozen_string_literal: true

module SolidQueueTui
  module Components
    class StatsBar
      STAT_CONFIGS = [
        { key: :ready,     label: "Ready",       color: :green },
        { key: :claimed,   label: "In Progress", color: :yellow },
        { key: :scheduled, label: "Scheduled",   color: :blue },
        { key: :failed,    label: "Failed",      color: :red },
        { key: :blocked,   label: "Blocked",     color: :magenta }
      ].freeze

      def initialize(tui, stats:)
        @tui = tui
        @stats = stats
      end

      def render(frame, area)
        top, bottom = @tui.layout_split(
          area,
          direction: :vertical,
          constraints: [
            @tui.constraint_length(1),
            @tui.constraint_length(1)
          ]
        )

        render_counts(frame, top)
        render_summary(frame, bottom)
      end

      private

      def render_counts(frame, area)
        spans = [
          @tui.text_span(content: " ", style: @tui.style(fg: :white))
        ]

        STAT_CONFIGS.each_with_index do |config, idx|
          value = @stats.send(config[:key])

          spans << @tui.text_span(
            content: config[:label],
            style: @tui.style(fg: :dark_gray)
          )
          spans << @tui.text_span(content: " ", style: @tui.style(fg: :white))
          spans << @tui.text_span(
            content: format_number(value),
            style: @tui.style(fg: config[:color], modifiers: [:bold])
          )

          if idx < STAT_CONFIGS.size - 1
            spans << @tui.text_span(
              content: "  |  ",
              style: @tui.style(fg: :dark_gray)
            )
          end
        end

        frame.render_widget(
          @tui.paragraph(text: [@tui.text_line(spans: spans)]),
          area
        )
      end

      def render_summary(frame, area)
        spans = [
          @tui.text_span(content: " Total Jobs: ", style: @tui.style(fg: :dark_gray)),
          @tui.text_span(
            content: format_number(@stats.total_jobs),
            style: @tui.style(fg: :white, modifiers: [:bold])
          ),
          @tui.text_span(content: "  Completed: ", style: @tui.style(fg: :dark_gray)),
          @tui.text_span(
            content: format_number(@stats.completed_jobs),
            style: @tui.style(fg: :green)
          ),
          @tui.text_span(content: "  Processes: ", style: @tui.style(fg: :dark_gray)),
          @tui.text_span(
            content: format_number(@stats.process_count),
            style: @tui.style(fg: :cyan, modifiers: [:bold])
          )
        ]

        frame.render_widget(
          @tui.paragraph(text: [@tui.text_line(spans: spans)]),
          area
        )
      end

      def format_number(n)
        return "0" if n.nil? || n == 0
        n.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
      end
    end
  end
end
