# frozen_string_literal: true

require_relative "../test_helper"

class PaginatableTest < Minitest::Test
  class PaginateHost
    include SolidQueueTui::Views::Paginatable

    def initialize
      init_pagination
    end

    # Expose private methods for testing
    public :update_items, :append_items, :needs_more?, :move_selection,
           :jump_to_top, :jump_to_bottom
  end

  def setup
    @host = PaginateHost.new
  end

  # --- initial state ---

  def test_initial_state
    assert_equal [], @host.items
    assert_equal 0, @host.current_offset
    assert_nil @host.selected_item
  end

  # --- update_items ---

  def test_update_items
    @host.update_items(%w[a b c])
    assert_equal %w[a b c], @host.items
    assert_equal "a", @host.selected_item
  end

  def test_update_items_clamps_selected_row
    @host.update_items(%w[a b c d e])
    @host.move_selection(4) # select last (index 4)
    @host.update_items(%w[x y]) # shrinks — selected_row resets to 0 since 4 >= 2
    assert_equal "x", @host.selected_item
  end

  def test_update_items_empty
    @host.update_items([])
    assert_nil @host.selected_item
  end

  def test_update_items_sets_all_loaded_when_under_page_size
    SolidQueueTui.page_size = 100
    @host.update_items(Array.new(50, "x"))
    # all_loaded should be true because 50 < 100
    # Verify by checking needs_more? at the end
    @host.move_selection(49)
    refute @host.needs_more?
  end

  # --- selected_item ---

  def test_selected_item_returns_correct_item
    @host.update_items(%w[a b c])
    @host.move_selection(2)
    assert_equal "c", @host.selected_item
  end

  def test_selected_item_empty_list
    assert_nil @host.selected_item
  end

  # --- move_selection ---

  def test_move_selection_down
    @host.update_items(%w[a b c])
    @host.move_selection(1)
    assert_equal "b", @host.selected_item
  end

  def test_move_selection_clamps_at_bottom
    @host.update_items(%w[a b c])
    @host.move_selection(10)
    assert_equal "c", @host.selected_item
  end

  def test_move_selection_clamps_at_top
    @host.update_items(%w[a b c])
    @host.move_selection(1)
    @host.move_selection(-10)
    assert_equal "a", @host.selected_item
  end

  def test_move_selection_empty_noop
    @host.update_items([])
    @host.move_selection(1) # should not raise
    assert_nil @host.selected_item
  end

  # --- append_items ---

  def test_append_items
    @host.update_items(%w[a b])
    @host.append_items(%w[c d])
    assert_equal %w[a b c d], @host.items
  end

  # --- needs_more? ---

  def test_needs_more_when_near_end_and_not_all_loaded
    SolidQueueTui.page_size = 100
    items = Array.new(100, "x") # exactly page_size → not all_loaded=false because !(100 < 100) is true... wait
    # update_items sets @all_loaded = new_items.size < page_size
    # 100 < 100 is false, so @all_loaded = false
    @host.update_items(items)
    @host.move_selection(95) # near the end, within LOAD_THRESHOLD
    assert @host.needs_more?
  end

  def test_needs_more_false_when_all_loaded
    SolidQueueTui.page_size = 100
    @host.update_items(Array.new(50, "x")) # 50 < 100 → all_loaded
    @host.move_selection(49)
    refute @host.needs_more?
  end

  # --- jump_to_top / bottom ---

  def test_jump_to_top
    @host.update_items(%w[a b c])
    @host.move_selection(2)
    @host.jump_to_top
    assert_equal "a", @host.selected_item
  end

  def test_jump_to_bottom
    @host.update_items(%w[a b c])
    @host.jump_to_bottom
    assert_equal "c", @host.selected_item
  end

  def test_jump_to_bottom_empty_noop
    @host.jump_to_bottom # should not raise
    assert_nil @host.selected_item
  end

  # --- reset_pagination! ---

  def test_reset_pagination
    @host.update_items(%w[a b c])
    @host.move_selection(2)
    @host.reset_pagination!

    assert_equal [], @host.items
    assert_nil @host.selected_item
    assert_equal 0, @host.current_offset
  end

  # --- current_offset ---

  def test_current_offset_reflects_items_size
    @host.update_items(%w[a b c])
    assert_equal 3, @host.current_offset
  end

  # --- all_loaded detection ---

  def test_all_loaded_exact_page_size
    SolidQueueTui.page_size = 3
    @host.update_items(%w[a b c]) # 3 < 3 is false → not all loaded
    @host.move_selection(2)
    assert @host.needs_more?
  ensure
    SolidQueueTui.page_size = 100
  end

  def test_all_loaded_under_page_size
    SolidQueueTui.page_size = 5
    @host.update_items(%w[a b c]) # 3 < 5 → all loaded
    @host.move_selection(2)
    refute @host.needs_more?
  ensure
    SolidQueueTui.page_size = 100
  end
end
