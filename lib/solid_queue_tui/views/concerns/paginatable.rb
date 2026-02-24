# frozen_string_literal: true

module SolidQueueTui
  module Views
    module Paginatable
      LOAD_THRESHOLD = 10

      def init_pagination
        @table_state = RatatuiRuby::TableState.new(nil)
        @table_state.select(0)
        @selected_row = 0
        @items = []
        @total_count = nil
        @all_loaded = false
      end

      def items = @items

      def selected_item
        return nil if @items.empty? || @selected_row >= @items.size
        @items[@selected_row]
      end

      def total_count=(count)
        @total_count = count
      end

      def current_offset
        @items.size
      end

      def reset_pagination!
        @items = []
        @total_count = nil
        @all_loaded = false
        @selected_row = 0
        @table_state.select(0)
      end

      private

      def update_items(new_items)
        @selected_row = 0 if @selected_row >= new_items.size
        @items = new_items
        @all_loaded = new_items.size < SolidQueueTui.page_size
        @selected_row = @selected_row.clamp(0, [@items.size - 1, 0].max)
        @table_state.select(@selected_row)
      end

      def append_items(more_items)
        @items.concat(more_items)
        @all_loaded = more_items.size < SolidQueueTui.page_size
      end

      def needs_more?
        !@all_loaded && @selected_row >= @items.size - LOAD_THRESHOLD
      end

      def move_selection(delta)
        return if @items.empty?
        @selected_row = (@selected_row + delta).clamp(0, @items.size - 1)
        @table_state.select(@selected_row)
        :load_more if needs_more?
      end

      def jump_to_top
        @selected_row = 0
        @table_state.select(0)
      end

      def jump_to_bottom
        return if @items.empty?
        @selected_row = @items.size - 1
        @table_state.select(@selected_row)
        :load_more if needs_more?
      end
    end
  end
end
