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

      def self.retry_all(filter: nil, queue: nil)
        scope = SolidQueue::FailedExecution.joins(:job)
        scope = scope.merge(SolidQueue::Job.where("class_name LIKE ?", "%#{filter}%")) if filter.present?
        scope = scope.merge(SolidQueue::Job.where(queue_name: queue)) if queue.present?
        count = scope.count
        return 0 if count == 0

        jobs = SolidQueue::Job.where(id: scope.select(:job_id))
        SolidQueue::FailedExecution.retry_all(jobs)
        count
      rescue => e
        0
      end
    end
  end
end
