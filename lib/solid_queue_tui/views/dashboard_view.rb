# frozen_string_literal: true

module SolidQueueTui
  module Views
    class DashboardView
      include FormattingHelpers

      def initialize(tui)
        @tui = tui
        @selected_row = 0
      end

      def update(stats:)
        @stats = stats
      end

      def render(frame, area)
        top, bottom = @tui.layout_split(
          area,
          direction: :vertical,
          constraints: [
            @tui.constraint_length(7),
            @tui.constraint_fill(1)
          ]
        )

        render_overview_panels(frame, top)
        render_completion(frame, bottom)
      end

      def handle_input(event)
        nil
      end

      def selected_item
        nil
      end

      def bindings
        [
          { key: "Tab", action: "Next View" },
          { key: "Shift Tab", action: "Prev View" },
        ]
      end

      def breadcrumb = "dashboard"

      private

      def render_overview_panels(frame, area)
        return unless @stats

        left, right = @tui.layout_split(
          area,
          direction: :horizontal,
          constraints: [
            @tui.constraint_percentage(50),
            @tui.constraint_percentage(50)
          ]
        )

        render_job_status_panel(frame, left)
        render_process_panel(frame, right)
      end

      def render_job_status_panel(frame, area)
        lines = [
          status_line("Ready", @stats.ready, :green),
          status_line("In Progress", @stats.claimed, :yellow),
          status_line("Scheduled", @stats.scheduled, :blue),
          status_line("Failed", @stats.failed, :red),
          status_line("Blocked", @stats.blocked, :magenta)
        ].compact

        frame.render_widget(
          @tui.paragraph(
            text: lines,
            block: @tui.block(
              title: " Job Status ",
              title_style: @tui.style(fg: :cyan, modifiers: [:bold]),
              borders: [:all],
              border_type: :rounded,
              border_style: @tui.style(fg: :dark_gray)
            )
          ),
          area
        )
      end

      def render_process_panel(frame, area)
        lines = if @stats.processes_by_kind.empty?
          [@tui.text_line(spans: [
            @tui.text_span(content: "  No active processes", style: @tui.style(fg: :dark_gray))
          ])]
        else
          @stats.processes_by_kind.map do |kind, count|
            color = case kind
                    when "Worker" then :green
                    when "Dispatcher" then :yellow
                    when "Scheduler" then :blue
                    else :white
                    end

            @tui.text_line(spans: [
              @tui.text_span(content: "  #{kind.ljust(18)}", style: @tui.style(fg: color)),
              @tui.text_span(content: count.to_s.rjust(6), style: @tui.style(fg: :cyan, modifiers: [:bold]))
            ])
          end
        end

        total_line = @tui.text_line(spans: [
          @tui.text_span(content: "  Total", style: @tui.style(fg: :dark_gray)),
          @tui.text_span(content: @stats.process_count.to_s.rjust(19), style: @tui.style(fg: :white, modifiers: [:bold]))
        ])
        lines << total_line

        frame.render_widget(
          @tui.paragraph(
            text: lines,
            block: @tui.block(
              title: " Processes ",
              title_style: @tui.style(fg: :cyan, modifiers: [:bold]),
              borders: [:all],
              border_type: :rounded,
              border_style: @tui.style(fg: :dark_gray)
            )
          ),
          area
        )
      end

      def render_completion(frame, area)
        return unless @stats

        lines = [
          @tui.text_line(spans: [
            @tui.text_span(content: "  Total: ", style: @tui.style(fg: :dark_gray)),
            @tui.text_span(content: format_number(@stats.total_jobs), style: @tui.style(fg: :white, modifiers: [:bold])),
            @tui.text_span(content: "   Completed: ", style: @tui.style(fg: :dark_gray)),
            @tui.text_span(content: format_number(@stats.completed_jobs), style: @tui.style(fg: :green))
          ])
        ]

        if @stats.total_jobs > 0
          completed_ratio = @stats.completed_jobs.to_f / @stats.total_jobs
          bar_width = 40
          filled = (completed_ratio * bar_width).round
          empty = bar_width - filled

          lines << @tui.text_line(spans: [
            @tui.text_span(content: "  Completion: ", style: @tui.style(fg: :dark_gray)),
            @tui.text_span(content: "#{'█' * filled}#{'░' * empty}", style: @tui.style(fg: :green)),
            @tui.text_span(content: " #{(completed_ratio * 100).round(1)}%", style: @tui.style(fg: :white))
          ])
        end

        frame.render_widget(
          @tui.paragraph(
            text: lines,
            block: @tui.block(
              title: " Overview ",
              title_style: @tui.style(fg: :cyan, modifiers: [:bold]),
              borders: [:all],
              border_type: :rounded,
              border_style: @tui.style(fg: :dark_gray)
            )
          ),
          area
        )
      end

      def status_line(label, value, color)
        bar_char = value.to_i > 0 ? "●" : "○"
        @tui.text_line(spans: [
          @tui.text_span(content: "  #{bar_char} ", style: @tui.style(fg: color)),
          @tui.text_span(content: label.ljust(14), style: @tui.style(fg: :white)),
          @tui.text_span(
            content: format_number(value).rjust(8),
            style: @tui.style(fg: color, modifiers: [:bold])
          )
        ])
      end

    end
  end
end
