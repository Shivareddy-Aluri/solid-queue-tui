# frozen_string_literal: true

module SolidQueueTui
  module Views
    class DashboardView
      include FormattingHelpers

      def initialize(tui)
        @tui = tui
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
        render_metrics(frame, bottom)
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

      # --- Top panels (sticky) ---

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

      # --- Bottom section: chart + queue summary ---

      def render_metrics(frame, area)
        return unless @stats

        chart_area, summary_area = @tui.layout_split(
          area,
          direction: :vertical,
          constraints: [
            @tui.constraint_percentage(70),
            @tui.constraint_percentage(30)
          ]
        )

        render_throughput_chart(frame, chart_area)
        render_queue_summary(frame, summary_area)
      end

      def render_throughput_chart(frame, area)
        enqueued = @stats.enqueued_per_hour
        processed = @stats.processed_per_hour
        failed = @stats.failed_per_hour

        # Convert 24-element arrays to [x, y] coordinate pairs
        enqueued_data = to_chart_data(enqueued)
        processed_data = to_chart_data(processed)
        failed_data = to_chart_data(failed)

        # Y-axis bounds
        all_values = [enqueued&.data, processed&.data, failed&.data].compact.flatten
        y_max = (all_values.max || 10).to_f
        y_max = 10.0 if y_max == 0

        # X-axis labels at key positions
        now = Time.now.utc
        x_labels = [0, 6, 12, 18, 23].map do |i|
          (now - (23 - i) * 3600).strftime("%H:%M")
        end

        # Y-axis labels
        y_labels = ["0", format_number((y_max / 2).round), format_number(y_max.round)]

        datasets = []
        if enqueued_data.any?
          datasets << RatatuiRuby::Widgets::Dataset.new(
            name: "Enqueued",
            data: enqueued_data,
            style: @tui.style(fg: :cyan),
            marker: :braille,
            graph_type: :line
          )
        end

        if processed_data.any?
          datasets << RatatuiRuby::Widgets::Dataset.new(
            name: "Processed",
            data: processed_data,
            style: @tui.style(fg: :green),
            marker: :braille,
            graph_type: :line
          )
        end

        if failed_data.any?
          datasets << RatatuiRuby::Widgets::Dataset.new(
            name: "Failed",
            data: failed_data,
            style: @tui.style(fg: :red),
            marker: :braille,
            graph_type: :line
          )
        end

        x_axis = RatatuiRuby::Widgets::Axis.new(
          bounds: [0.0, 23.0],
          labels: x_labels,
          style: @tui.style(fg: :dark_gray)
        )

        y_axis = RatatuiRuby::Widgets::Axis.new(
          bounds: [0.0, y_max],
          labels: y_labels,
          style: @tui.style(fg: :dark_gray)
        )

        chart = @tui.chart(
          datasets: datasets,
          x_axis: x_axis,
          y_axis: y_axis,
          block: @tui.block(
            title: " Throughput (24h) ",
            title_style: @tui.style(fg: :cyan, modifiers: [:bold]),
            borders: [:all],
            border_type: :rounded,
            border_style: @tui.style(fg: :dark_gray)
          ),
          legend_position: :top_right
        )

        frame.render_widget(chart, area)
      end

      def render_queue_summary(frame, area)
        lines = []

        # Queue depth bars (top 5 by depth)
        queue_depths = @stats.queue_depths
        if queue_depths.any?
          total_depth = queue_depths.values.sum
          sorted = queue_depths.sort_by { |_, v| -v }
          top_queues = sorted.first(5)
          remaining = sorted.drop(5)
          max_depth = top_queues.first&.last || 1

          top_queues.each do |name, count|
            pct = total_depth > 0 ? (count.to_f / total_depth * 100).round(1) : 0
            bar_width = 20
            filled = max_depth > 0 ? (count.to_f / max_depth * bar_width).round : 0
            empty_bar = bar_width - filled

            lines << @tui.text_line(spans: [
              @tui.text_span(content: "  #{name.ljust(14)}", style: @tui.style(fg: :white)),
              @tui.text_span(content: "#{"█" * filled}", style: @tui.style(fg: :cyan)),
              @tui.text_span(content: "#{"░" * empty_bar}", style: @tui.style(fg: :dark_gray)),
              @tui.text_span(content: "  #{format_number(count).rjust(6)} (#{pct}%)", style: @tui.style(fg: :dark_gray))
            ])
          end

          if remaining.any?
            others_count = remaining.sum { |_, v| v }
            pct = total_depth > 0 ? (others_count.to_f / total_depth * 100).round(1) : 0
            lines << @tui.text_line(spans: [
              @tui.text_span(content: "  +#{remaining.size} more", style: @tui.style(fg: :dark_gray)),
              @tui.text_span(content: "  #{format_number(others_count).rjust(26)} (#{pct}%)", style: @tui.style(fg: :dark_gray))
            ])
          end
        else
          lines << @tui.text_line(spans: [
            @tui.text_span(content: "  No queued jobs", style: @tui.style(fg: :dark_gray))
          ])
        end

        # Separator
        lines << @tui.text_line(spans: [
          @tui.text_span(content: "", style: @tui.style(fg: :dark_gray))
        ])

        # Throughput totals
        enq_total = @stats.enqueued_per_hour&.total || 0
        proc_total = @stats.processed_per_hour&.total || 0
        fail_total = @stats.failed_per_hour&.total || 0

        lines << @tui.text_line(spans: [
          @tui.text_span(content: "  24h ", style: @tui.style(fg: :dark_gray)),
          @tui.text_span(content: "Enqueued: ", style: @tui.style(fg: :cyan)),
          @tui.text_span(content: format_number(enq_total), style: @tui.style(fg: :white, modifiers: [:bold])),
          @tui.text_span(content: "  Processed: ", style: @tui.style(fg: :green)),
          @tui.text_span(content: format_number(proc_total), style: @tui.style(fg: :white, modifiers: [:bold])),
          @tui.text_span(content: "  Failed: ", style: @tui.style(fg: :red)),
          @tui.text_span(content: format_number(fail_total), style: @tui.style(fg: :white, modifiers: [:bold]))
        ])

        # Overall summary + completion bar
        lines << @tui.text_line(spans: [
          @tui.text_span(content: "  Total: ", style: @tui.style(fg: :dark_gray)),
          @tui.text_span(content: format_number(@stats.total_jobs), style: @tui.style(fg: :white, modifiers: [:bold])),
          @tui.text_span(content: "   Completed: ", style: @tui.style(fg: :dark_gray)),
          @tui.text_span(content: format_number(@stats.completed_jobs), style: @tui.style(fg: :green, modifiers: [:bold]))
        ])

        if @stats.total_jobs > 0
          ratio = @stats.completed_jobs.to_f / @stats.total_jobs
          bar_w = 40
          filled = (ratio * bar_w).round
          empty_bar = bar_w - filled

          lines << @tui.text_line(spans: [
            @tui.text_span(content: "  ", style: @tui.style(fg: :dark_gray)),
            @tui.text_span(content: "#{"█" * filled}", style: @tui.style(fg: :green)),
            @tui.text_span(content: "#{"░" * empty_bar}", style: @tui.style(fg: :dark_gray)),
            @tui.text_span(content: " #{(ratio * 100).round(1)}%", style: @tui.style(fg: :white))
          ])
        end

        frame.render_widget(
          @tui.paragraph(
            text: lines,
            block: @tui.block(
              title: " Queue Depth & Summary ",
              title_style: @tui.style(fg: :cyan, modifiers: [:bold]),
              borders: [:all],
              border_type: :rounded,
              border_style: @tui.style(fg: :dark_gray)
            )
          ),
          area
        )
      end

      # --- Helpers ---

      def to_chart_data(result)
        return [] unless result
        result.data.each_with_index.map { |v, i| [i.to_f, v.to_f] }
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
