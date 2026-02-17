# frozen_string_literal: true

module SolidQueueTui
  module Actions
    class RetryJob
      def self.call(failed_execution_id)
        fe = SolidQueue::FailedExecution.find(failed_execution_id)
        fe.retry
        true
      rescue ActiveRecord::RecordNotFound
        false
      rescue => e
        false
      end

      def self.retry_all
        jobs = SolidQueue::Job.joins(:failed_execution)
        count = jobs.count
        return 0 if count == 0

        SolidQueue::FailedExecution.retry_all(jobs)
        count
      rescue => e
        0
      end
    end
  end
end
