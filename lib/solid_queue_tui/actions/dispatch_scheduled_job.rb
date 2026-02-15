# frozen_string_literal: true

module SolidQueueTui
  module Actions
    class DispatchScheduledJob
      def self.call(job_id)
        conn = ActiveRecord::Base.connection

        row = conn.select_one(
          "SELECT se.id, se.job_id, j.queue_name, j.priority " \
            "FROM solid_queue_scheduled_executions se " \
            "JOIN solid_queue_jobs j ON j.id = se.job_id " \
            "WHERE j.id = #{conn.quote(job_id.to_i)}"
        )
        return false unless row

        conn.transaction do
          conn.execute(
            "INSERT INTO solid_queue_ready_executions (job_id, queue_name, priority, created_at) " \
              "VALUES (#{conn.quote(row['job_id'])}, #{conn.quote(row['queue_name'])}, " \
              "#{conn.quote(row['priority'])}, #{conn.quote(Time.now.utc.iso8601)})"
          )

          conn.execute(
            "DELETE FROM solid_queue_scheduled_executions WHERE id = #{conn.quote(row['id'])}"
          )
        end

        true
      rescue => e
        false
      end
    end
  end
end