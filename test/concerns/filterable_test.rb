# frozen_string_literal: true

require_relative "../test_helper"

class FilterableTest < Minitest::Test
  class FilterHost
    include SolidQueueTui::Views::Filterable

    def initialize
      init_filter
      @table_state = RatatuiRuby::TableState.new(nil)
      @selected_row = 0
    end
  end

  def setup
    @host = FilterHost.new
  end

  # --- initial state ---

  def test_initial_state
    refute @host.filter_mode?
    assert_equal({}, @host.filters)
  end

  # --- enter / exit filter mode ---

  def test_enter_filter_mode
    @host.enter_filter_mode
    assert @host.filter_mode?
  end

  def test_esc_exits_filter_mode
    @host.enter_filter_mode
    @host.handle_filter_input({ type: :key, code: "esc" })
    refute @host.filter_mode?
  end

  # --- typing characters ---

  def test_typing_chars
    @host.enter_filter_mode
    @host.handle_filter_input({ type: :key, code: "A" })
    @host.handle_filter_input({ type: :key, code: "b" })

    # Apply to inspect the result
    @host.handle_filter_input({ type: :key, code: "enter" })
    assert_equal({ class_name: "Ab" }, @host.filters)
  end

  # --- backspace ---

  def test_backspace_deletes_last_char
    @host.enter_filter_mode
    @host.handle_filter_input({ type: :key, code: "A" })
    @host.handle_filter_input({ type: :key, code: "b" })
    @host.handle_filter_input({ type: :key, code: "backspace" })
    @host.handle_filter_input({ type: :key, code: "enter" })

    assert_equal({ class_name: "A" }, @host.filters)
  end

  def test_backspace_on_empty_field
    @host.enter_filter_mode
    @host.handle_filter_input({ type: :key, code: "backspace" })
    @host.handle_filter_input({ type: :key, code: "enter" })

    assert_equal({}, @host.filters)
  end

  # --- tab switches fields ---

  def test_tab_switches_to_next_field
    @host.enter_filter_mode
    @host.handle_filter_input({ type: :key, code: "tab" })
    @host.handle_filter_input({ type: :key, code: "q" })
    @host.handle_filter_input({ type: :key, code: "enter" })

    assert_equal({ queue: "q" }, @host.filters)
  end

  def test_tab_wraps_around
    @host.enter_filter_mode
    # Two tabs cycles back to first field (2 fields total)
    @host.handle_filter_input({ type: :key, code: "tab" })
    @host.handle_filter_input({ type: :key, code: "tab" })
    @host.handle_filter_input({ type: :key, code: "X" })
    @host.handle_filter_input({ type: :key, code: "enter" })

    assert_equal({ class_name: "X" }, @host.filters)
  end

  # --- enter applies filter ---

  def test_enter_applies_and_exits_filter_mode
    @host.enter_filter_mode
    @host.handle_filter_input({ type: :key, code: "t" })
    result = @host.handle_filter_input({ type: :key, code: "enter" })

    refute @host.filter_mode?
    assert_equal :refresh, result
    assert_equal({ class_name: "t" }, @host.filters)
  end

  # --- esc cancels and restores ---

  def test_esc_restores_previous_filters
    # Apply a filter first
    @host.enter_filter_mode
    @host.handle_filter_input({ type: :key, code: "A" })
    @host.handle_filter_input({ type: :key, code: "enter" })

    # Enter again, type something different, then cancel
    @host.enter_filter_mode
    @host.handle_filter_input({ type: :key, code: "Z" })
    @host.handle_filter_input({ type: :key, code: "esc" })

    # Original filter should be preserved
    assert_equal({ class_name: "A" }, @host.filters)
  end

  # --- clear_filter ---

  def test_clear_filter
    @host.enter_filter_mode
    @host.handle_filter_input({ type: :key, code: "x" })
    @host.handle_filter_input({ type: :key, code: "enter" })

    result = @host.clear_filter
    assert_equal :refresh, result
    assert_equal({}, @host.filters)
  end

  # --- filter_title ---

  def test_filter_title_no_filters
    assert_equal "Jobs", @host.filter_title("Jobs")
  end

  def test_filter_title_with_filters
    @host.enter_filter_mode
    @host.handle_filter_input({ type: :key, code: "A" })
    @host.handle_filter_input({ type: :key, code: "enter" })

    assert_equal "Jobs (class: A)", @host.filter_title("Jobs")
  end

  # --- clear_filter_binding ---

  def test_clear_filter_binding_when_empty
    assert_nil @host.clear_filter_binding
  end

  def test_clear_filter_binding_when_active
    @host.enter_filter_mode
    @host.handle_filter_input({ type: :key, code: "x" })
    @host.handle_filter_input({ type: :key, code: "enter" })

    expected = { key: "c", action: "Clear Filter" }
    assert_equal expected, @host.clear_filter_binding
  end
end
