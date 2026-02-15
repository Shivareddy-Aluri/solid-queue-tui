# frozen_string_literal: true

module SolidQueueTui
  module Data
    class Stats
      attr_reader :ready, :claimed, :failed, :scheduled, :blocked,
                  :total_jobs, :completed_jobs, :process_count,
                  :processes_by_kind

      def initialize(data)
        @ready = data[:ready]
        @claimed = data[:claimed]
        @failed = data[:failed]
        @scheduled = data[:scheduled]
        @blocked = data[:blocked]
        @total_jobs = data[:total_jobs]
        @completed_jobs = data[:completed_jobs]
        @process_count = data[:process_count]
        @processes_by_kind = data[:processes_by_kind]
      end

      def self.fetch
        conn = ActiveRecord::Base.connection

        new(
          ready: count_table(conn, "solid_queue_ready_executions"),
          claimed: count_table(conn, "solid_queue_claimed_executions"),
          failed: count_table(conn, "solid_queue_failed_executions"),
          scheduled: count_table(conn, "solid_queue_scheduled_executions"),
          blocked: count_table(conn, "solid_queue_blocked_executions"),
          total_jobs: count_table(conn, "solid_queue_jobs"),
          completed_jobs: count_where(conn, "solid_queue_jobs", "finished_at IS NOT NULL"),
          process_count: count_table(conn, "solid_queue_processes"),
          processes_by_kind: processes_by_kind(conn)
        )
      rescue => e
        empty(error: e.message)
      end

      def self.empty(error: nil)
        new(
          ready: 0, claimed: 0, failed: 0, scheduled: 0, blocked: 0,
          total_jobs: 0, completed_jobs: 0, process_count: 0,
          processes_by_kind: {}
        )
      end

      private_class_method def self.count_table(conn, table)
        conn.select_value("SELECT COUNT(*) FROM #{table}").to_i
      end

      private_class_method def self.count_where(conn, table, condition)
        conn.select_value("SELECT COUNT(*) FROM #{table} WHERE #{condition}").to_i
      end

      private_class_method def self.processes_by_kind(conn)
        rows = conn.select_rows(
          "SELECT kind, COUNT(*) FROM solid_queue_processes GROUP BY kind"
        )
        rows.to_h { |kind, count| [kind, count.to_i] }
      end

    end
  end
end
