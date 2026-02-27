# frozen_string_literal: true

require_relative "test_helper"

class FormattingHelpersTest < Minitest::Test
  include SolidQueueTui::FormattingHelpers

  # --- time_ago ---

  def test_time_ago_nil
    assert_equal "n/a", time_ago(nil)
  end

  def test_time_ago_seconds
    assert_equal "30s ago", time_ago(Time.now.utc - 30)
  end

  def test_time_ago_minutes
    assert_equal "5m ago", time_ago(Time.now.utc - 300)
  end

  def test_time_ago_hours
    assert_equal "2h ago", time_ago(Time.now.utc - 7200)
  end

  def test_time_ago_days
    assert_equal "3d ago", time_ago(Time.now.utc - 259_200)
  end

  def test_time_ago_just_now
    assert_equal "0s ago", time_ago(Time.now.utc)
  end

  # --- format_time ---

  def test_format_time_nil
    assert_equal "n/a", format_time(nil)
  end

  def test_format_time_valid
    t = Time.utc(2024, 3, 15, 10, 30, 45)
    assert_equal "2024-03-15 10:30:45", format_time(t)
  end

  # --- format_duration ---

  def test_format_duration_nil
    assert_equal "n/a", format_duration(nil)
  end

  def test_format_duration_sub_second
    assert_equal "<1s", format_duration(0.5)
  end

  def test_format_duration_zero
    assert_equal "<1s", format_duration(0)
  end

  def test_format_duration_seconds
    assert_equal "45s", format_duration(45)
  end

  def test_format_duration_minutes
    assert_equal "2m 30s", format_duration(150)
  end

  def test_format_duration_hours
    assert_equal "1h 30m", format_duration(5400)
  end

  def test_format_duration_days
    assert_equal "2d 3h", format_duration(183_600)
  end

  # --- format_number ---

  def test_format_number_nil
    assert_equal "0", format_number(nil)
  end

  def test_format_number_zero
    assert_equal "0", format_number(0)
  end

  def test_format_number_small
    assert_equal "42", format_number(42)
  end

  def test_format_number_thousands
    assert_equal "1,234", format_number(1234)
  end

  def test_format_number_millions
    assert_equal "1,234,567", format_number(1_234_567)
  end

  def test_format_number_hundred
    assert_equal "999", format_number(999)
  end

  # --- truncate ---

  def test_truncate_nil
    assert_equal "", truncate(nil, 10)
  end

  def test_truncate_short_string
    assert_equal "hello", truncate("hello", 10)
  end

  def test_truncate_exact_length
    assert_equal "hello", truncate("hello", 5)
  end

  def test_truncate_long_string
    assert_equal "hello w...", truncate("hello world!", 10)
  end

  # --- humanize_duration ---

  def test_humanize_duration_seconds
    assert_equal "45s", humanize_duration(45)
  end

  def test_humanize_duration_minutes
    assert_equal "5m", humanize_duration(300)
  end

  def test_humanize_duration_hours
    assert_equal "2h", humanize_duration(7200)
  end

  def test_humanize_duration_days
    assert_equal "1d", humanize_duration(86_400)
  end

  def test_humanize_duration_negative
    assert_equal "5m", humanize_duration(-300)
  end

  def test_humanize_duration_zero
    assert_equal "0s", humanize_duration(0)
  end

  # --- time_until ---

  def test_time_until_nil
    assert_equal "n/a", time_until(nil)
  end

  def test_time_until_past
    assert_equal "now", time_until(Time.now.utc - 60)
  end

  def test_time_until_future
    result = time_until(Time.now.utc + 360)
    assert_match(/\Ain [56]m\z/, result)
  end

  def test_time_until_just_now
    assert_equal "now", time_until(Time.now.utc)
  end
end
