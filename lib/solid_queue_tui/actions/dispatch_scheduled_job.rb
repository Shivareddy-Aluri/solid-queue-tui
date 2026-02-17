# frozen_string_literal: true

module SolidQueueTui
  module Actions
    class DispatchScheduledJob
      def self.call(job_id)
        SolidQueue::ScheduledExecution.dispatch_jobs([job_id])
        true
      rescue ActiveRecord::RecordNotFound
        false
      rescue => e
        false
      end
    end
  end
end
