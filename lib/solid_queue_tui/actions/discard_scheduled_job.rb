# frozen_string_literal: true

module SolidQueueTui
  module Actions
    class DiscardScheduledJob
      def self.call(job_id)
        conn = ActiveRecord::Base.connection

        row = conn.select_one(
          "SELECT se.id, se.job_id " \
            "FROM solid_queue_scheduled_executions se " \
            "WHERE se.job_id = #{conn.quote(job_id.to_i)}"
        )
        return false unless row

        conn.transaction do
          conn.execute(
            "DELETE FROM solid_queue_scheduled_executions WHERE id = #{conn.quote(row['id'])}"
          )

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