# frozen_string_literal: true

module SolidQueueTui
  module Actions
    class DiscardScheduledJob
      def self.call(job_id)
        se = SolidQueue::ScheduledExecution.find_by!(job_id: job_id)
        se.discard
        true
      rescue ActiveRecord::RecordNotFound
        false
      rescue => e
        false
      end
    end
  end
end
