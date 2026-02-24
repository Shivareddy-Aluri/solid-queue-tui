# frozen_string_literal: true

module SolidQueueTui
  module Views
    class JobDetailView
      PANE_ERROR = 0
      PANE_INFO  = 1

      def initialize(tui)
        @tui = tui
        @job = nil
        @failed_job = nil
        @scroll_offset = 0
        @confirm_action = nil
        @active_pane = PANE_ERROR
      end

      def show(job: nil, failed_job: nil)
        @job = job
        @failed_job = failed_job
        @scroll_offset = 0
        @confirm_action = nil
        @active_pane = PANE_ERROR
        @active = true
      end

      def hide
        @active = false
        @job = nil
        @failed_job = nil
        @confirm_action = nil
      end

      def active? = @active

      def render(frame, area)
        return unless @active

        if @failed_job
          render_failed_detail(frame, area)
        elsif @job
          render_job_detail(frame, area)
        end

        if @confirm_action
          popup_area = area.centered(
            @tui.constraint_percentage(50),
            @tui.constraint_length(5)
          )
          frame.render_widget(@tui.clear(), popup_area)
          render_confirm(frame, popup_area)
        end
      end

      def handle_input(event)
        if @confirm_action
          handle_confirm_input(event)
        else
          handle_normal_input(event)
        end
      end

      def bindings
        if @confirm_action
          [
            { key: "y", action: "Confirm" },
            { key: "n/Esc", action: "Cancel" }
          ]
        else
          b = [
            { key: "Esc", action: "Close" },
            { key: "j/k", action: "Scroll" }
          ]
          if @failed_job
            b += [
              { key: "Tab", action: "Switch Pane" },
              { key: "c", action: "Copy Pane" },
              { key: "R", action: "Retry" },
              { key: "D", action: "Discard" }
            ]
          end
          b
        end
      end

      def breadcrumb
        if @failed_job
          pane = @active_pane == PANE_ERROR ? "error" : "info"
          "failed:#{@failed_job.job_id}:#{pane}"
        elsif @job
          "jobs:#{@job.id}"
        else
          "detail"
        end
      end

      private

      def handle_normal_input(event)
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
        in { type: :key, code: "tab" } | { type: :key, code: "back_tab" }
          toggle_pane if @failed_job
          nil
        in { type: :key, code: "c" }
          copy_active_pane if @failed_job
          nil
        in { type: :key, code: "R" }
          @confirm_action = :retry if @failed_job
          nil
        in { type: :key, code: "D" }
          @confirm_action = :discard if @failed_job
          nil
        else
          nil
        end
      end

      def handle_confirm_input(event)
        case event
        in { type: :key, code: "y" }
          action = @confirm_action
          @confirm_action = nil
          case action
          when :retry
            Actions::RetryJob.call(@failed_job.id)
            hide
            :refresh
          when :discard
            Actions::DiscardJob.call(@failed_job.id)
            hide
            :refresh
          end
        in { type: :key, code: "n" } | { type: :key, code: "esc" }
          @confirm_action = nil
          nil
        else
          nil
        end
      end

      def toggle_pane
        @active_pane = @active_pane == PANE_ERROR ? PANE_INFO : PANE_ERROR
      end

      def copy_active_pane
        text = if @active_pane == PANE_ERROR
                 error_pane_text
               else
                 info_pane_text
               end
        Clipboard.copy(text)
      end

      def error_pane_text
        lines = []
        lines << "Exception: #{@failed_job.error_class}"
        lines << "Message: #{@failed_job.error_message}"
        if @failed_job.backtrace.is_a?(Array)
          lines << ""
          lines << "Backtrace:"
          @failed_job.backtrace.each { |bt| lines << "  #{bt}" }
        end
        lines.join("\n")
      end

      def info_pane_text
        lines = []
        lines << "Job ID: #{@failed_job.job_id}"
        lines << "Active Job ID: #{@failed_job.active_job_id || "n/a"}"
        lines << "Class: #{@failed_job.class_name}"
        lines << "Queue: #{@failed_job.queue_name}"
        lines << "Priority: #{@failed_job.priority}"
        lines << "Created At: #{format_time(@failed_job.created_at)}"
        lines << "Failed At: #{format_time(@failed_job.failed_at)}"
        if @failed_job.arguments.is_a?(Hash) || @failed_job.arguments.is_a?(Array)
          lines << ""
          lines << "Arguments:"
          lines << (JSON.pretty_generate(@failed_job.arguments) rescue @failed_job.arguments.to_s)
        end
        lines.join("\n")
      end

      def render_confirm(frame, area)
        message = case @confirm_action
                  when :retry
                    "Retry job ##{@failed_job.job_id} (#{@failed_job.class_name})? [y/n]"
                  when :discard
                    "Discard job ##{@failed_job.job_id} (#{@failed_job.class_name})? This cannot be undone. [y/n]"
                  end

        frame.render_widget(
          @tui.paragraph(
            text: " #{message}",
            style: @tui.style(fg: :yellow, modifiers: [:bold]),
            block: @tui.block(
              title: " Confirm ",
              title_style: @tui.style(fg: :red, modifiers: [:bold]),
              borders: [:all],
              border_type: :rounded,
              border_style: @tui.style(fg: :red)
            )
          ),
          area
        )
      end

      def render_failed_detail(frame, area)
        left_area, right_area = @tui.layout_split(
          area,
          direction: :horizontal,
          constraints: [
            @tui.constraint_percentage(50),
            @tui.constraint_percentage(50)
          ]
        )

        left_active = @active_pane == PANE_ERROR
        right_active = @active_pane == PANE_INFO

        # Left pane: Error details + backtrace
        error_lines = []
        error_lines << section_header("Exception")
        error_lines << detail_line("Class", @failed_job.error_class)
        error_lines << detail_line("Message", @failed_job.error_message)
        error_lines << empty_line

        if @failed_job.backtrace.is_a?(Array) && !@failed_job.backtrace.empty?
          error_lines << section_header("Backtrace")
          @failed_job.backtrace.first(30).each do |bt_line|
            error_lines << @tui.text_line(spans: [
              @tui.text_span(content: "  #{bt_line}", style: @tui.style(fg: :dark_gray))
            ])
          end
        end

        visible_error_lines = error_lines.drop(@scroll_offset)
        left_border_color = left_active ? :red : :dark_gray

        frame.render_widget(
          @tui.paragraph(
            text: visible_error_lines,
            block: @tui.block(
              title: " Error Details ",
              title_style: @tui.style(fg: left_active ? :red : :dark_gray, modifiers: left_active ? [:bold] : []),
              borders: [:all],
              border_type: :rounded,
              border_style: @tui.style(fg: left_border_color),
              style: @tui.style(fg: :white)
            )
          ),
          left_area
        )

        # Right pane: Job info + arguments
        info_lines = []
        info_lines << section_header("Job Information")
        info_lines << detail_line("Job ID", @failed_job.job_id.to_s)
        info_lines << detail_line("Active Job ID", @failed_job.active_job_id || "n/a")
        info_lines << detail_line("Class", @failed_job.class_name)
        info_lines << detail_line("Queue", @failed_job.queue_name)
        info_lines << detail_line("Priority", @failed_job.priority.to_s)
        info_lines << detail_line("Created At", format_time(@failed_job.created_at))
        info_lines << detail_line("Failed At", format_time(@failed_job.failed_at))

        if @failed_job.arguments.is_a?(Hash) || @failed_job.arguments.is_a?(Array)
          info_lines << empty_line
          info_lines << section_header("Arguments")
          args_str = JSON.pretty_generate(@failed_job.arguments) rescue @failed_job.arguments.to_s
          args_str.split("\n").each do |arg_line|
            info_lines << @tui.text_line(spans: [
              @tui.text_span(content: "  #{arg_line}", style: @tui.style(fg: :white))
            ])
          end
        end

        right_border_color = right_active ? :cyan : :dark_gray

        frame.render_widget(
          @tui.paragraph(
            text: info_lines,
            block: @tui.block(
              title: " Job Info ",
              title_style: @tui.style(fg: right_active ? :cyan : :dark_gray, modifiers: right_active ? [:bold] : []),
              titles: [
                { content: " Esc:Close  R:Retry  D:Discard ",
                  position: :bottom, alignment: :right }
              ],
              borders: [:all],
              border_type: :rounded,
              border_style: @tui.style(fg: right_border_color),
              style: @tui.style(fg: :white)
            )
          ),
          right_area
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

        if @job.arguments.is_a?(Hash) || @job.arguments.is_a?(Array)
          lines << empty_line
          lines << section_header("Arguments")
          args_str = JSON.pretty_generate(@job.arguments) rescue @job.arguments.to_s
          args_str.split("\n").each do |arg_line|
            lines << @tui.text_line(spans: [
              @tui.text_span(content: "  #{arg_line}", style: @tui.style(fg: :white))
            ])
          end
        end

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

    end
  end
end
