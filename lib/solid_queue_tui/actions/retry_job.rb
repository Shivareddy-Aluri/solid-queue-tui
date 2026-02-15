# frozen_string_literal: true

module SolidQueueTui
  module Actions
    class RetryJob
      def self.call(failed_execution_id)
        conn = ActiveRecord::Base.connection

        # Get the failed execution and its job
        row = conn.select_one(
          "SELECT fe.id, fe.job_id, j.queue_name, j.priority " \
          "FROM solid_queue_failed_executions fe " \
          "JOIN solid_queue_jobs j ON j.id = fe.job_id " \
          "WHERE fe.id = #{conn.quote(failed_execution_id.to_i)}"
        )
        return false unless row

        conn.transaction do
          # Create a ready execution for the job
          conn.execute(
            "INSERT INTO solid_queue_ready_executions (job_id, queue_name, priority, created_at) " \
            "VALUES (#{conn.quote(row['job_id'])}, #{conn.quote(row['queue_name'])}, " \
            "#{conn.quote(row['priority'])}, #{conn.quote(Time.now.utc.iso8601)})"
          )

          # Remove the failed execution
          conn.execute(
            "DELETE FROM solid_queue_failed_executions WHERE id = #{conn.quote(failed_execution_id.to_i)}"
          )

          # Clear finished_at on the job
          conn.execute(
            "UPDATE solid_queue_jobs SET finished_at = NULL " \
            "WHERE id = #{conn.quote(row['job_id'])}"
          )
        end

        true
      rescue => e
        false
      end

      def self.retry_all
        conn = ActiveRecord::Base.connection

        rows = conn.select_all(
          "SELECT fe.id, fe.job_id, j.queue_name, j.priority " \
          "FROM solid_queue_failed_executions fe " \
          "JOIN solid_queue_jobs j ON j.id = fe.job_id"
        )

        count = 0
        rows.each do |row|
          conn.transaction do
            conn.execute(
              "INSERT INTO solid_queue_ready_executions (job_id, queue_name, priority, created_at) " \
              "VALUES (#{conn.quote(row['job_id'])}, #{conn.quote(row['queue_name'])}, " \
              "#{conn.quote(row['priority'])}, #{conn.quote(Time.now.utc.iso8601)})"
            )
            conn.execute(
              "DELETE FROM solid_queue_failed_executions WHERE id = #{conn.quote(row['id'])}"
            )
            conn.execute(
              "UPDATE solid_queue_jobs SET finished_at = NULL WHERE id = #{conn.quote(row['job_id'])}"
            )
            count += 1
          end
        rescue
          next
        end

        count
      end
    end
  end
end
