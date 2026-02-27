# frozen_string_literal: true

module SolidQueueTui
  module Views
    class QueuesView
      include Confirmable
      include Filterable
      include Paginatable
      include FormattingHelpers

      def initialize(tui)
        @tui = tui
        @mode = :list
        @selected_queue = nil

        # List mode state
        @list_table_state = RatatuiRuby::TableState.new(nil)
        @list_table_state.select(0)
        @list_selected_row = 0
        @queues = []

        # Detail mode state (via Paginatable + Filterable)
        init_pagination
        init_confirm
        init_filter
      end

      def detail_mode? = @mode == :detail

      def selected_queue_name
        @selected_queue&.name
      end

      def update(queues:)
        @queues = queues
        @list_selected_row = @list_selected_row.clamp(0, [@queues.size - 1, 0].max)
        @list_table_state.select(@list_selected_row)
      end

      def update_detail(jobs:)
        update_items(jobs)
      end

      def append(jobs:)
        append_items(jobs)
      end

      def render(frame, area)
        if @mode == :list
          render_list(frame, area)
        else
          render_detail(frame, area)
        end
      end

      def handle_input(event)
        if @mode == :list
          handle_list_input(event)
        elsif confirm_mode?
          handle_confirm_input(event)
        elsif filter_mode?
          handle_filter_input(event)
        else
          handle_detail_input(event)
        end
      end

      def selected_item
        if @mode == :list
          return nil if @queues.empty? || @list_selected_row >= @queues.size
          @queues[@list_selected_row]
        else
          return nil if items.empty? || @selected_row >= items.size
          items[@selected_row]
        end
      end

      def capturing_input?
        detail_mode? || confirm_mode? || filter_mode?
      end

      def bindings
        if @mode == :list
          if confirm_mode?
            confirm_bindings
          else
            [
              { key: "j/k", action: "Navigate" },
              { key: "Enter", action: "View Jobs" },
              { key: "p", action: "Pause/Resume" },
              { key: "G/g", action: "Bottom/Top" }
            ]
          end
        else
          if confirm_mode?
            confirm_bindings
          elsif filter_mode?
            filter_bindings
          else
            [
              { key: "j/k", action: "Navigate" },
              { key: "Enter", action: "Detail" },
              { key: "/", action: "Filter" },
              clear_filter_binding,
              { key: "Esc", action: "Back" },
              { key: "G/g", action: "Bottom/Top" }
            ].compact
          end
        end
      end

      def breadcrumb
        if @mode == :list
          "queues"
        else
          base = "queues > #{@selected_queue&.name}"
          @filters.empty? ? base : "#{base}:filtered"
        end
      end

      private

      # === List mode ===

      def handle_list_input(event)
        if confirm_mode?
          return handle_confirm_input(event)
        end

        case event
        in { type: :key, code: "j" } | { type: :key, code: "up" }
          list_move_selection(-1)
        in { type: :key, code: "k" } | { type: :key, code: "down" }
          list_move_selection(1)
        in { type: :key, code: "g" }
          list_jump_to_top
        in { type: :key, code: "G" }
          list_jump_to_bottom
        in { type: :key, code: "enter" }
          enter_detail_mode
        in { type: :key, code: "p" }
          queue = selected_item
          if queue
            @confirm_action = queue.paused ? :resume : :pause
          end
          nil
        else
          nil
        end
      end

      def enter_detail_mode
        queue = selected_item
        return nil unless queue
        @selected_queue = queue
        @mode = :detail
        reset_pagination!
        clear_filter
        :enter_queue
      end

      def list_move_selection(delta)
        return if @queues.empty?
        @list_selected_row = (@list_selected_row + delta).clamp(0, @queues.size - 1)
        @list_table_state.select(@list_selected_row)
        nil
      end

      def list_jump_to_top
        @list_selected_row = 0
        @list_table_state.select(0)
        nil
      end

      def list_jump_to_bottom
        return nil if @queues.empty?
        @list_selected_row = @queues.size - 1
        @list_table_state.select(@list_selected_row)
        nil
      end

      def render_list(frame, area)
        if confirm_mode?
          render_list_table(frame, area)
          render_confirm_popup(frame, area)
        else
          render_list_table(frame, area)
        end
      end

      def render_list_table(frame, area)
        columns = [
          { key: :name,   label: "QUEUE",   width: :fill },
          { key: :size,   label: "SIZE",    width: 10 },
          { key: :status, label: "STATUS",  width: 10, color_by: :status }
        ]

        rows = @queues.map do |q|
          {
            name: q.name,
            size: q.size,
            status: q.paused ? "paused" : "active"
          }
        end

        table = Components::JobTable.new(
          @tui,
          title: "Queues",
          columns: columns,
          rows: rows,
          selected_row: @list_selected_row,
          empty_message: "No queues found"
        )

        table.render(frame, area, @list_table_state)
      end

      # === Detail mode ===

      def handle_detail_input(event)
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
        in { type: :key, code: "enter" }
          :open_detail
        in { type: :key, code: "/" }
          enter_filter_mode
          nil
        in { type: :key, code: "c" }
          clear_filter
        in { type: :key, code: "esc" }
          exit_detail_mode
        else
          nil
        end
      end

      def exit_detail_mode
        @mode = :list
        @selected_queue = nil
        :exit_queue
      end

      def render_detail(frame, area)
        if filter_mode?
          filter_area, content_area = @tui.layout_split(
            area,
            direction: :vertical,
            constraints: [
              @tui.constraint_length(3),
              @tui.constraint_fill(1)
            ]
          )
          render_filter_input(frame, filter_area)
          render_detail_table(frame, content_area)
        else
          render_detail_table(frame, area)
        end
      end

      def render_detail_table(frame, area)
        columns = [
          { key: :id,         label: "ID",       width: 8 },
          { key: :class_name, label: "CLASS",    width: :fill },
          { key: :priority,   label: "PRI",      width: 5 },
          { key: :created_at, label: "ENQUEUED", width: 12 }
        ]

        rows = items.map do |job|
          {
            id: job.id,
            class_name: job.class_name,
            priority: job.priority,
            created_at: time_ago(job.created_at)
          }
        end

        table = Components::JobTable.new(
          @tui,
          title: filter_title("Queue '#{@selected_queue&.name}' — Pending"),
          columns: columns,
          rows: rows,
          selected_row: @selected_row,
          total_count: @total_count,
          empty_message: "No pending jobs in this queue"
        )

        table.render(frame, area, @table_state)
      end

      # === Confirmable hooks (list mode only) ===

      def confirm_message
        queue = @queues[@list_selected_row]
        if @confirm_action == :pause
          "Pause queue '#{queue&.name}'? Workers will stop picking up jobs from this queue. [y/n]"
        else
          "Resume queue '#{queue&.name}'? [y/n]"
        end
      end

      def execute_confirm_action(action)
        queue = @queues[@list_selected_row]
        return nil unless queue
        Actions::ToggleQueuePause.call(queue.name)
        :refresh
      end

    end
  end
end
