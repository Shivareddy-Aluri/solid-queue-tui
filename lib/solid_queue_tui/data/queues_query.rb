# frozen_string_literal: true

module SolidQueueTui
  module Data
    class QueuesQuery
      QueueInfo = Struct.new(
        :name, :ready, :claimed, :scheduled, :blocked, :failed, :paused,
        keyword_init: true
      ) do
        def total
          ready + claimed + scheduled + blocked + failed
        end
      end

      def self.fetch
        conn = ActiveRecord::Base.connection

        queues = distinct_queues(conn)
        paused = paused_queues(conn)

        queues.map do |name|
          QueueInfo.new(
            name: name,
            ready: count_for(conn, "solid_queue_ready_executions", name),
            claimed: claimed_for(conn, name),
            scheduled: count_for(conn, "solid_queue_scheduled_executions", name),
            blocked: count_for(conn, "solid_queue_blocked_executions", name),
            failed: failed_for(conn, name),
            paused: paused.include?(name)
          )
        end
      rescue => e
        []
      end

      private_class_method def self.distinct_queues(conn)
        conn.select_values(
          "SELECT DISTINCT queue_name FROM solid_queue_jobs WHERE queue_name IS NOT NULL ORDER BY queue_name"
        )
      end

      private_class_method def self.paused_queues(conn)
        conn.select_values("SELECT queue_name FROM solid_queue_pauses")
      end

      private_class_method def self.count_for(conn, table, queue_name)
        conn.select_value(
          "SELECT COUNT(*) FROM #{table} WHERE queue_name = #{conn.quote(queue_name)}"
        ).to_i
      end

      private_class_method def self.claimed_for(conn, queue_name)
        conn.select_value(
          "SELECT COUNT(*) FROM solid_queue_claimed_executions ce " \
          "JOIN solid_queue_jobs j ON j.id = ce.job_id " \
          "WHERE j.queue_name = #{conn.quote(queue_name)}"
        ).to_i
      end

      private_class_method def self.failed_for(conn, queue_name)
        conn.select_value(
          "SELECT COUNT(*) FROM solid_queue_failed_executions fe " \
          "JOIN solid_queue_jobs j ON j.id = fe.job_id " \
          "WHERE j.queue_name = #{conn.quote(queue_name)}"
        ).to_i
      end
    end
  end
end
