# frozen_string_literal: true

module SolidQueueTui
  module Data
    class FailedQuery
      FailedJob = Struct.new(
        :id, :job_id, :queue_name, :class_name, :priority,
        :error_class, :error_message, :backtrace,
        :active_job_id, :arguments, :failed_at, :created_at,
        keyword_init: true
      )

      def self.fetch(filter: nil, queue: nil, limit: 100, offset: 0)
        scope = SolidQueue::FailedExecution.joins(:job).includes(:job)
        scope = scope.merge(SolidQueue::Job.where("class_name LIKE ?", "%#{filter}%")) if filter.present?
        scope = scope.merge(SolidQueue::Job.where(queue_name: queue)) if queue.present?
        scope = scope.order(created_at: :desc).offset(offset).limit(limit)

        scope.map { |fe| build_failed_job(fe) }
      rescue => e
        Rails.logger.tagged("SQTUI") { Rails.logger.error("FailedQuery.fetch error: #{e.class}: #{e.message}") } if defined?(Rails) && Rails.logger
        []
      end

      def self.count(filter: nil, queue: nil)
        scope = SolidQueue::FailedExecution.joins(:job)
        scope = scope.merge(SolidQueue::Job.where("class_name LIKE ?", "%#{filter}%")) if filter.present?
        scope = scope.merge(SolidQueue::Job.where(queue_name: queue)) if queue.present?
        scope.count
      rescue => e
        Rails.logger.tagged("SQTUI") { Rails.logger.error("FailedQuery.count error: #{e.class}: #{e.message}") } if defined?(Rails) && Rails.logger
        0
      end

      def self.fetch_one(id)
        fe = SolidQueue::FailedExecution.includes(:job).find_by(id: id)
        return nil unless fe

        build_failed_job(fe)
      rescue => e
        nil
      end

      def self.build_failed_job(fe)
        job = fe.job
        FailedJob.new(
          id: fe.id,
          job_id: job.id,
          queue_name: job.queue_name,
          class_name: job.class_name,
          priority: job.priority,
          error_class: fe.exception_class || "Unknown",
          error_message: fe.message || "No message",
          backtrace: fe.backtrace || [],
          active_job_id: job.active_job_id,
          arguments: job.arguments,
          failed_at: fe.created_at,
          created_at: job.created_at
        )
      end
      private_class_method :build_failed_job
    end
  end
end
