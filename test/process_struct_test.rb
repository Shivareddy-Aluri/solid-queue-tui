# frozen_string_literal: true

require_relative "test_helper"

class ProcessStructTest < Minitest::Test
  ProcessStruct = SolidQueueTui::Data::ProcessesQuery::Process

  # --- alive? ---

  def test_alive_recent_heartbeat
    p = build_process(last_heartbeat_at: Time.now.utc - 10)
    assert p.alive?
  end

  def test_alive_stale_heartbeat
    p = build_process(last_heartbeat_at: Time.now.utc - 120)
    refute p.alive?
  end

  def test_alive_nil_heartbeat
    p = build_process(last_heartbeat_at: nil)
    refute p.alive?
  end

  def test_alive_custom_threshold
    p = build_process(last_heartbeat_at: Time.now.utc - 30)
    assert p.alive?(threshold: 60)
    refute p.alive?(threshold: 10)
  end

  # --- uptime ---

  def test_uptime_normal
    created = Time.now.utc - 3600
    p = build_process(created_at: created)
    assert_in_delta 3600, p.uptime, 2
  end

  def test_uptime_nil_created_at
    p = build_process(created_at: nil)
    assert_nil p.uptime
  end

  # --- queues ---

  def test_queues_from_metadata
    p = build_process(metadata: { "queues" => ["default", "mailers"] })
    assert_equal ["default", "mailers"], p.queues
  end

  def test_queues_nil_metadata
    p = build_process(metadata: nil)
    assert_equal [], p.queues
  end

  def test_queues_missing_key
    p = build_process(metadata: { "threads" => 5 })
    assert_equal [], p.queues
  end

  # --- thread_count ---

  def test_thread_count_threads_key
    p = build_process(metadata: { "threads" => 5 })
    assert_equal 5, p.thread_count
  end

  def test_thread_count_polling_interval_key
    p = build_process(metadata: { "polling_interval" => 10 })
    assert_equal 10, p.thread_count
  end

  def test_thread_count_nil_metadata
    p = build_process(metadata: nil)
    assert_nil p.thread_count
  end

  private

  def build_process(**attrs)
    defaults = {
      id: 1, kind: "Worker", pid: 123, hostname: "localhost",
      name: "worker-1", last_heartbeat_at: Time.now.utc,
      supervisor_id: nil, metadata: {}, created_at: Time.now.utc
    }
    ProcessStruct.new(**defaults.merge(attrs))
  end
end
