# frozen_string_literal: true

module SolidQueueTui
  module Actions
    class DiscardJob
      def self.call(failed_execution_id)
        conn = ActiveRecord::Base.connection

        row = conn.select_one(
          "SELECT fe.id, fe.job_id FROM solid_queue_failed_executions fe " \
          "WHERE fe.id = #{conn.quote(failed_execution_id.to_i)}"
        )
        return false unless row

        conn.transaction do
          # Remove the failed execution
          conn.execute(
            "DELETE FROM solid_queue_failed_executions WHERE id = #{conn.quote(failed_execution_id.to_i)}"
          )

          # Mark the job as finished (discarded)
          conn.execute(
            "UPDATE solid_queue_jobs SET finished_at = #{conn.quote(Time.now.utc.iso8601)} " \
            "WHERE id = #{conn.quote(row['job_id'])}"
          )
        end

        true
      rescue => e
        false
      end
    end
  end
end
