# frozen_string_literal: true

module SolidQueueTui
  module Data
    class JobsQuery
      Job = Struct.new(
        :id, :queue_name, :class_name, :priority, :status,
        :active_job_id, :scheduled_at, :finished_at, :created_at,
        keyword_init: true
      )

      def self.fetch(filter: nil, queue: nil, status: nil, limit: 200)
        conn = ActiveRecord::Base.connection

        sql = <<~SQL
          SELECT
            j.id,
            j.queue_name,
            j.class_name,
            j.priority,
            j.active_job_id,
            j.scheduled_at,
            j.finished_at,
            j.created_at,
            CASE
              WHEN fe.id IS NOT NULL THEN 'failed'
              WHEN ce.id IS NOT NULL THEN 'claimed'
              WHEN re.id IS NOT NULL THEN 'ready'
              WHEN se.id IS NOT NULL THEN 'scheduled'
              WHEN be.id IS NOT NULL THEN 'blocked'
              WHEN j.finished_at IS NOT NULL THEN 'completed'
              ELSE 'unknown'
            END AS status
          FROM solid_queue_jobs j
          LEFT JOIN solid_queue_failed_executions fe ON fe.job_id = j.id
          LEFT JOIN solid_queue_claimed_executions ce ON ce.job_id = j.id
          LEFT JOIN solid_queue_ready_executions re ON re.job_id = j.id
          LEFT JOIN solid_queue_scheduled_executions se ON se.job_id = j.id
          LEFT JOIN solid_queue_blocked_executions be ON be.job_id = j.id
        SQL

        conditions = []
        conditions << sanitize(conn, "j.queue_name = %s", queue) if queue
        conditions << sanitize(conn, status_condition(status)) if status
        if filter && !filter.empty?
          conditions << sanitize(conn, "j.class_name LIKE %s", "%#{filter}%")
        end

        sql += " WHERE #{conditions.join(' AND ')}" unless conditions.empty?
        sql += " ORDER BY j.id DESC LIMIT #{limit.to_i}"

        rows = conn.select_all(sql)
        rows.map do |row|
          Job.new(
            id: row["id"].to_i,
            queue_name: row["queue_name"],
            class_name: row["class_name"],
            priority: row["priority"].to_i,
            status: row["status"],
            active_job_id: row["active_job_id"],
            scheduled_at: parse_time(row["scheduled_at"]),
            finished_at: parse_time(row["finished_at"]),
            created_at: parse_time(row["created_at"])
          )
        end
      rescue => e
        []
      end

      private_class_method def self.status_condition(status)
        case status
        when "failed"    then "fe.id IS NOT NULL"
        when "claimed"   then "ce.id IS NOT NULL"
        when "ready"     then "re.id IS NOT NULL"
        when "scheduled" then "se.id IS NOT NULL"
        when "blocked"   then "be.id IS NOT NULL"
        when "completed" then "j.finished_at IS NOT NULL"
        else "1=1"
        end
      end

      private_class_method def self.sanitize(conn, template, *values)
        return template if values.empty?
        template.gsub("%s") { conn.quote(values.shift) }
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
