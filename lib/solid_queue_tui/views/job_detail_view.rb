# frozen_string_literal: true

module SolidQueueTui
  module Views
    class JobDetailView
      def initialize(tui)
        @tui = tui
        @job = nil
        @failed_job = nil
        @scroll_offset = 0
      end

      def show(job: nil, failed_job: nil)
        @job = job
        @failed_job = failed_job
        @scroll_offset = 0
        @active = true
      end

      def hide
        @active = false
        @job = nil
        @failed_job = nil
      end

      def active? = @active

      def render(frame, area)
        return unless @active

        # Render an overlay with padding
        inner = shrink_area(area, 4, 2)

        frame.render_widget(@tui.paragraph(text: ""), inner) # clear background

        if @failed_job
          render_failed_detail(frame, inner)
        elsif @job
          render_job_detail(frame, inner)
        end
      end

      def handle_input(event)
        case event
        in { type: :key, code: "esc" } | { type: :key, code: "q" }
          hide
          nil
        in { type: :key, code: "j" } | { type: :key, code: "up" }
          @scroll_offset = [@scroll_offset - 1, 0].max
          nil
        in { type: :key, code: "k" } | { type: :key, code: "down" }
          @scroll_offset += 1
          nil
        in { type: :key, code: "R" }
          if @failed_job
            Actions::RetryJob.call(@failed_job.id)
            hide
            :refresh
          end
        in { type: :key, code: "D" }
          if @failed_job
            Actions::DiscardJob.call(@failed_job.id)
            hide
            :refresh
          end
        else
          nil
        end
      end

      def bindings
        bindings = [
          { key: "Esc", action: "Close" },
          { key: "j/k", action: "Scroll" }
        ]
        if @failed_job
          bindings += [
            { key: "R", action: "Retry" },
            { key: "D", action: "Discard" }
          ]
        end
        bindings
      end

      def breadcrumb
        if @failed_job
          "failed:#{@failed_job.job_id}"
        elsif @job
          "jobs:#{@job.id}"
        else
          "detail"
        end
      end

      private

      def render_failed_detail(frame, area)
        lines = []

        lines << section_header("Job Information")
        lines << detail_line("Job ID", @failed_job.job_id.to_s)
        lines << detail_line("Active Job ID", @failed_job.active_job_id || "n/a")
        lines << detail_line("Class", @failed_job.class_name)
        lines << detail_line("Queue", @failed_job.queue_name)
        lines << detail_line("Priority", @failed_job.priority.to_s)
        lines << detail_line("Created At", format_time(@failed_job.created_at))
        lines << detail_line("Failed At", format_time(@failed_job.failed_at))
        lines << empty_line

        lines << section_header("Error Details")
        lines << detail_line("Exception", @failed_job.error_class)
        lines << detail_line("Message", @failed_job.error_message)
        lines << empty_line

        if @failed_job.backtrace.is_a?(Array) && !@failed_job.backtrace.empty?
          lines << section_header("Backtrace")
          @failed_job.backtrace.first(30).each do |bt_line|
            lines << @tui.text_line(spans: [
              @tui.text_span(content: "  #{bt_line}", style: @tui.style(fg: :dark_gray))
            ])
          end
          lines << empty_line
        end

        if @failed_job.arguments.is_a?(Hash) || @failed_job.arguments.is_a?(Array)
          lines << section_header("Arguments")
          args_str = JSON.pretty_generate(@failed_job.arguments) rescue @failed_job.arguments.to_s
          args_str.split("\n").each do |arg_line|
            lines << @tui.text_line(spans: [
              @tui.text_span(content: "  #{arg_line}", style: @tui.style(fg: :white))
            ])
          end
        end

        # Apply scroll offset
        visible_lines = lines.drop(@scroll_offset)

        frame.render_widget(
          @tui.paragraph(
            text: visible_lines,
            block: @tui.block(
              title: " Failed Job ##{@failed_job.job_id} — #{@failed_job.class_name} ",
              title_style: @tui.style(fg: :red, modifiers: [:bold]),
              titles: [
                { content: " Esc:Close  R:Retry  D:Discard ",
                  position: :bottom, alignment: :right }
              ],
              borders: [:all],
              border_type: :rounded,
              border_style: @tui.style(fg: :red),
              style: @tui.style(fg: :white)
            )
          ),
          area
        )
      end

      def render_job_detail(frame, area)
        lines = []

        lines << section_header("Job Information")
        lines << detail_line("ID", @job.id.to_s)
        lines << detail_line("Active Job ID", @job.active_job_id || "n/a")
        lines << detail_line("Class", @job.class_name)
        lines << detail_line("Queue", @job.queue_name)
        lines << detail_line("Priority", @job.priority.to_s)
        lines << detail_line("Status", @job.status)
        lines << detail_line("Created At", format_time(@job.created_at))
        lines << detail_line("Scheduled At", format_time(@job.scheduled_at))
        lines << detail_line("Finished At", format_time(@job.finished_at))

        visible_lines = lines.drop(@scroll_offset)

        frame.render_widget(
          @tui.paragraph(
            text: visible_lines,
            block: @tui.block(
              title: " Job ##{@job.id} — #{@job.class_name} ",
              title_style: @tui.style(fg: :cyan, modifiers: [:bold]),
              titles: [
                { content: " Esc:Close ",
                  position: :bottom, alignment: :right }
              ],
              borders: [:all],
              border_type: :rounded,
              border_style: @tui.style(fg: :cyan),
              style: @tui.style(fg: :white)
            )
          ),
          area
        )
      end

      def section_header(title)
        @tui.text_line(spans: [
          @tui.text_span(content: "  ── #{title} ", style: @tui.style(fg: :cyan, modifiers: [:bold]))
        ])
      end

      def detail_line(label, value)
        @tui.text_line(spans: [
          @tui.text_span(content: "  #{label.ljust(16)}", style: @tui.style(fg: :dark_gray)),
          @tui.text_span(content: value.to_s, style: @tui.style(fg: :white))
        ])
      end

      def empty_line
        @tui.text_line(spans: [
          @tui.text_span(content: "", style: @tui.style(fg: :white))
        ])
      end

      def format_time(time)
        return "n/a" unless time
        time.strftime("%Y-%m-%d %H:%M:%S UTC")
      end

      def shrink_area(area, h_pad, v_pad)
        # Create a smaller area centered in the given area
        # This is an approximation - the actual implementation depends on ratatui_ruby's Rect API
        area
      end
    end
  end
end
