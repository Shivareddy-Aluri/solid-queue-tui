# frozen_string_literal: true

module SolidQueueTui
  module Views
    class FailedView
      include Filterable


      LOAD_THRESHOLD = 10

      def initialize(tui)
        @tui = tui
        @table_state = RatatuiRuby::TableState.new(nil)
        @table_state.select(0)
        @selected_row = 0
        @failed_jobs = []
        @total_count = nil
        @all_loaded = false
        @confirm_action = nil
        init_filter
      end

      def update(failed_jobs:)
        @failed_jobs = failed_jobs
        @all_loaded = failed_jobs.size < SolidQueueTui.page_size
        @selected_row = @selected_row.clamp(0, [@failed_jobs.size - 1, 0].max)
        @table_state.select(@selected_row)
      end

      def append(failed_jobs:)
        @failed_jobs.concat(failed_jobs)
        @all_loaded = failed_jobs.size < SolidQueueTui.page_size
      end

      def total_count=(count)
        @total_count = count
      end

      def current_offset
        @failed_jobs.size
      end

      def reset_pagination!
        @failed_jobs = []
        @total_count = nil
        @all_loaded = false
        @selected_row = 0
        @table_state.select(0)
      end

      def render(frame, area)
        if @confirm_action
          confirm_area, content_area = @tui.layout_split(
            area,
            direction: :vertical,
            constraints: [
              @tui.constraint_length(3),
              @tui.constraint_fill(1)
            ]
          )
          render_confirm(frame, confirm_area)
          render_failed_table(frame, content_area)
        elsif filter_mode?
          filter_area, content_area = @tui.layout_split(
            area,
            direction: :vertical,
            constraints: [
              @tui.constraint_length(3),
              @tui.constraint_fill(1)
            ]
          )
          render_filter_input(frame, filter_area)
          render_failed_table(frame, content_area)
        else
          render_failed_table(frame, area)
        end
      end

      def handle_input(event)
        if @confirm_action
          handle_confirm_input(event)
        elsif filter_mode?
          handle_filter_input(event)
        else
          handle_normal_input(event)
        end
      end

      def selected_item
        return nil if @failed_jobs.empty? || @selected_row >= @failed_jobs.size
        @failed_jobs[@selected_row]
      end

      def bindings
        if @confirm_action
          [
            { key: "y", action: "Confirm" },
            { key: "n/Esc", action: "Cancel" }
          ]
        elsif filter_mode?
          filter_bindings
        else
          [
            { key: "j/k", action: "Navigate" },
            { key: "Enter", action: "Detail" },
            { key: "R", action: "Retry" },
            { key: "D", action: "Discard" },
            { key: "A", action: "Retry All" },
            { key: "/", action: "Filter" }
          ]
        end
      end

      def capturing_input?
        filter_mode? || @confirm_action
      end

      def breadcrumb
        @filters.empty? ? "failed" : "failed:filtered"
      end

      private

      def needs_more?
        !@all_loaded && @selected_row >= @failed_jobs.size - LOAD_THRESHOLD
      end

      def handle_normal_input(event)
        case event
        in { type: :key, code: "j" } | { type: :key, code: "up" }
          move_selection(-1)
        in { type: :key, code: "k" } | { type: :key, code: "down" }
          result = move_selection(1)
          return :load_more if result == :load_more
          nil
        in { type: :key, code: "g" }
          jump_to_top
        in { type: :key, code: "G" }
          jump_to_bottom
        in { type: :key, code: "R" }
          @confirm_action = :retry if selected_item
          nil
        in { type: :key, code: "D" }
          @confirm_action = :discard if selected_item
          nil
        in { type: :key, code: "A" }
          @confirm_action = :retry_all unless @failed_jobs.empty?
          nil
        in { type: :key, code: "/" }
          enter_filter_mode
          nil
        in { type: :key, code: "esc" }
          clear_filter
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
            item = selected_item
            return nil unless item
            Actions::RetryJob.call(item.id)
            :refresh
          when :discard
            item = selected_item
            return nil unless item
            Actions::DiscardJob.call(item.id)
            :refresh
          when :retry_all
            Actions::RetryJob.retry_all
            :refresh
          end
        in { type: :key, code: "n" } | { type: :key, code: "esc" }
          @confirm_action = nil
          nil
        else
          nil
        end
      end

      def move_selection(delta)
        return if @failed_jobs.empty?
        @selected_row = (@selected_row + delta).clamp(0, @failed_jobs.size - 1)
        @table_state.select(@selected_row)
        :load_more if needs_more?
      end

      def jump_to_top
        @selected_row = 0
        @table_state.select(0)
      end

      def jump_to_bottom
        return if @failed_jobs.empty?
        @selected_row = @failed_jobs.size - 1
        @table_state.select(@selected_row)
        return :load_more if needs_more?
      end

      def render_failed_table(frame, area)
        columns = [
          { key: :id,            label: "ID",         width: 8 },
          { key: :class_name,    label: "JOB CLASS",   width: :fill },
          { key: :queue_name,    label: "QUEUE",       width: 14 },
          { key: :error_class,   label: "ERROR CLASS",  width: :fill },
          { key: :error_message, label: "MESSAGE",      width: :fill },
          { key: :failed_at,     label: "FAILED",      width: 12 }
        ]

        rows = @failed_jobs.map do |job|
          {
            id: job.job_id,
            class_name: job.class_name,
            queue_name: job.queue_name,
            error_class: job.error_class,
            error_message: truncate(job.error_message, 40),
            failed_at: time_ago(job.failed_at)
          }
        end

        table = Components::JobTable.new(
          @tui,
          title: filter_title("Failed Jobs"),
          columns: columns,
          rows: rows,
          selected_row: @selected_row,
          total_count: @total_count,
          empty_message: "No failed jobs — everything is running smoothly!"
        )

        table.render(frame, area, @table_state)
      end

      def render_confirm(frame, area)
        message = case @confirm_action
                  when :retry
                    job = selected_item
                    "Retry job ##{job&.job_id} (#{job&.class_name})? [y/n]"
                  when :discard
                    job = selected_item
                    "Discard job ##{job&.job_id} (#{job&.class_name})? This cannot be undone. [y/n]"
                  when :retry_all
                    "Retry ALL #{@failed_jobs.size} failed jobs? [y/n]"
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

      def truncate(str, max)
        return "" unless str
        str.length > max ? "#{str[0...max - 3]}..." : str
      end

      def time_ago(time)
        return "n/a" unless time
        seconds = (Time.now.utc - time).to_i
        case seconds
        when 0..59       then "#{seconds}s ago"
        when 60..3599    then "#{seconds / 60}m ago"
        when 3600..86399 then "#{seconds / 3600}h ago"
        else "#{seconds / 86400}d ago"
        end
      end
    end
  end
end
