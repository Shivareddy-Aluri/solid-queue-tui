# frozen_string_literal: true

module SolidQueueTui
  module Data
    class JobsQuery
      Job = Struct.new(
        :id, :queue_name, :class_name, :priority, :status,
        :active_job_id, :concurrency_key,
        :scheduled_at, :finished_at, :created_at,
        :started_at, :worker_id, :expires_at,
        keyword_init: true
      )

      def self.fetch(status:, filter: nil, queue: nil, limit: 200)
        case status
        when "claimed"   then fetch_claimed(filter: filter, queue: queue, limit: limit)
        when "blocked"   then fetch_blocked(filter: filter, queue: queue, limit: limit)
        when "scheduled" then fetch_scheduled(filter: filter, queue: queue, limit: limit)
        when "completed" then fetch_finished(filter: filter, queue: queue, limit: limit)
        else []
        end
      rescue => e
        []
      end

      def self.fetch_claimed(filter: nil, queue: nil, limit: 200)
        conn = ActiveRecord::Base.connection

        sql = <<~SQL
          SELECT
            j.id, j.queue_name, j.class_name, j.priority,
            j.active_job_id, j.concurrency_key, j.created_at,
            ce.process_id AS worker_id,
            ce.created_at AS started_at
          FROM solid_queue_claimed_executions ce
          JOIN solid_queue_jobs j ON j.id = ce.job_id
        SQL

        conditions = []
        conditions << "j.queue_name = #{conn.quote(queue)}" if queue
        conditions << "j.class_name LIKE #{conn.quote("%#{filter}%")}" if filter && !filter.empty?

        sql += " WHERE #{conditions.join(' AND ')}" unless conditions.empty?
        sql += " ORDER BY ce.job_id ASC LIMIT #{limit.to_i}"

        conn.select_all(sql).map do |row|
          Job.new(
            id: row["id"].to_i,
            queue_name: row["queue_name"],
            class_name: row["class_name"],
            priority: row["priority"].to_i,
            status: "claimed",
            active_job_id: row["active_job_id"],
            concurrency_key: row["concurrency_key"],
            created_at: parse_time(row["created_at"]),
            worker_id: row["worker_id"]&.to_i,
            started_at: parse_time(row["started_at"])
          )
        end
      end

      def self.fetch_blocked(filter: nil, queue: nil, limit: 200)
        conn = ActiveRecord::Base.connection

        sql = <<~SQL
          SELECT
            j.id, j.queue_name, j.class_name, j.priority,
            j.active_job_id, j.concurrency_key, j.created_at,
            be.expires_at,
            be.created_at AS blocked_since
          FROM solid_queue_blocked_executions be
          JOIN solid_queue_jobs j ON j.id = be.job_id
        SQL

        conditions = []
        conditions << "j.queue_name = #{conn.quote(queue)}" if queue
        conditions << "j.class_name LIKE #{conn.quote("%#{filter}%")}" if filter && !filter.empty?

        sql += " WHERE #{conditions.join(' AND ')}" unless conditions.empty?
        sql += " ORDER BY be.job_id ASC LIMIT #{limit.to_i}"

        conn.select_all(sql).map do |row|
          Job.new(
            id: row["id"].to_i,
            queue_name: row["queue_name"],
            class_name: row["class_name"],
            priority: row["priority"].to_i,
            status: "blocked",
            active_job_id: row["active_job_id"],
            concurrency_key: row["concurrency_key"],
            created_at: parse_time(row["blocked_since"]),
            expires_at: parse_time(row["expires_at"])
          )
        end
      end

      # Scheduled: query from scheduled_executions JOIN jobs
      def self.fetch_scheduled(filter: nil, queue: nil, limit: 200)
        conn = ActiveRecord::Base.connection

        sql = <<~SQL
          SELECT
            j.id, j.queue_name, j.class_name, j.priority,
            j.active_job_id, j.created_at,
            se.scheduled_at
          FROM solid_queue_scheduled_executions se
          JOIN solid_queue_jobs j ON j.id = se.job_id
        SQL

        conditions = []
        conditions << "j.queue_name = #{conn.quote(queue)}" if queue
        conditions << "j.class_name LIKE #{conn.quote("%#{filter}%")}" if filter && !filter.empty?

        sql += " WHERE #{conditions.join(' AND ')}" unless conditions.empty?
        sql += " ORDER BY se.scheduled_at ASC, se.priority ASC LIMIT #{limit.to_i}"

        conn.select_all(sql).map do |row|
          Job.new(
            id: row["id"].to_i,
            queue_name: row["queue_name"],
            class_name: row["class_name"],
            priority: row["priority"].to_i,
            status: "scheduled",
            active_job_id: row["active_job_id"],
            scheduled_at: parse_time(row["scheduled_at"]),
            created_at: parse_time(row["created_at"])
          )
        end
      end

      # Finished: query from jobs WHERE finished_at IS NOT NULL
      def self.fetch_finished(filter: nil, queue: nil, limit: 200)
        conn = ActiveRecord::Base.connection

        sql = <<~SQL
          SELECT
            j.id, j.queue_name, j.class_name, j.priority,
            j.active_job_id, j.finished_at, j.created_at
          FROM solid_queue_jobs j
          WHERE j.finished_at IS NOT NULL
        SQL

        sql += " AND j.queue_name = #{conn.quote(queue)}" if queue
        sql += " AND j.class_name LIKE #{conn.quote("%#{filter}%")}" if filter && !filter.empty?
        sql += " ORDER BY j.finished_at DESC LIMIT #{limit.to_i}"

        conn.select_all(sql).map do |row|
          Job.new(
            id: row["id"].to_i,
            queue_name: row["queue_name"],
            class_name: row["class_name"],
            priority: row["priority"].to_i,
            status: "completed",
            active_job_id: row["active_job_id"],
            finished_at: parse_time(row["finished_at"]),
            created_at: parse_time(row["created_at"])
          )
        end
      end

      private_class_method def self.parse_time(value)
        return nil if value.nil?
        value.is_a?(Time) ? value : Time.parse(value.to_s)
      rescue
        nil
      end
    end
  end
end
