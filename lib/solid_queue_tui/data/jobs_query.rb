# frozen_string_literal: true

module SolidQueueTui
  module Data
    class JobsQuery
      Job = Struct.new(
        :id, :queue_name, :class_name, :priority, :status,
        :active_job_id, :concurrency_key, :arguments,
        :scheduled_at, :finished_at, :created_at,
        :started_at, :worker_id, :expires_at,
        keyword_init: true
      )

      def self.fetch(status:, filter: nil, queue: nil, limit: 100, offset: 0)
        case status
        when "claimed"   then fetch_claimed(filter: filter, queue: queue, limit: limit, offset: offset)
        when "blocked"   then fetch_blocked(filter: filter, queue: queue, limit: limit, offset: offset)
        when "scheduled" then fetch_scheduled(filter: filter, queue: queue, limit: limit, offset: offset)
        when "completed" then fetch_finished(filter: filter, queue: queue, limit: limit, offset: offset)
        else []
        end
      rescue => e
        []
      end

      def self.count(status:, filter: nil, queue: nil)
        case status
        when "claimed"   then count_scope(SolidQueue::ClaimedExecution.joins(:job), filter: filter, queue: queue)
        when "blocked"   then count_scope(SolidQueue::BlockedExecution.joins(:job), filter: filter, queue: queue)
        when "scheduled" then count_scope(SolidQueue::ScheduledExecution.joins(:job), filter: filter, queue: queue)
        when "completed" then count_finished(filter: filter, queue: queue)
        else 0
        end
      rescue => e
        0
      end

      def self.fetch_claimed(filter: nil, queue: nil, limit: 100, offset: 0)
        scope = SolidQueue::ClaimedExecution.joins(:job)
        scope = scope.merge(SolidQueue::Job.where(queue_name: queue)) if queue
        scope = apply_class_name_filter(scope, filter)
        scope = scope.order(job_id: :asc).offset(offset).limit(limit)

        scope.includes(:job).map do |ce|
          job = ce.job
          Job.new(
            id: job.id,
            queue_name: job.queue_name,
            class_name: job.class_name,
            priority: job.priority,
            status: "claimed",
            active_job_id: job.active_job_id,
            concurrency_key: job.concurrency_key,
            created_at: job.created_at,
            worker_id: ce.process_id,
            started_at: ce.created_at
          )
        end
      end

      def self.fetch_blocked(filter: nil, queue: nil, limit: 100, offset: 0)
        scope = SolidQueue::BlockedExecution.joins(:job)
        scope = scope.merge(SolidQueue::Job.where(queue_name: queue)) if queue
        scope = apply_class_name_filter(scope, filter)
        scope = scope.order(job_id: :asc).offset(offset).limit(limit)

        scope.includes(:job).map do |be|
          job = be.job
          Job.new(
            id: job.id,
            queue_name: job.queue_name,
            class_name: job.class_name,
            priority: job.priority,
            status: "blocked",
            active_job_id: job.active_job_id,
            concurrency_key: job.concurrency_key,
            created_at: be.created_at,
            expires_at: be.expires_at
          )
        end
      end

      def self.fetch_scheduled(filter: nil, queue: nil, limit: 100, offset: 0)
        scope = SolidQueue::ScheduledExecution.joins(:job)
        scope = scope.merge(SolidQueue::Job.where(queue_name: queue)) if queue
        scope = apply_class_name_filter(scope, filter)
        scope = scope.order(scheduled_at: :asc, priority: :asc).offset(offset).limit(limit)

        scope.includes(:job).map do |se|
          job = se.job
          Job.new(
            id: job.id,
            queue_name: job.queue_name,
            class_name: job.class_name,
            priority: job.priority,
            status: "scheduled",
            active_job_id: job.active_job_id,
            arguments: job.arguments,
            scheduled_at: se.scheduled_at,
            created_at: job.created_at
          )
        end
      end

      def self.fetch_finished(filter: nil, queue: nil, limit: 100, offset: 0)
        scope = SolidQueue::Job.finished
        scope = scope.where(queue_name: queue) if queue
        scope = scope.where("class_name LIKE ?", "%#{filter}%") if filter.present?
        scope = scope.order(finished_at: :desc).offset(offset).limit(limit)

        scope.map do |job|
          Job.new(
            id: job.id,
            queue_name: job.queue_name,
            class_name: job.class_name,
            priority: job.priority,
            status: "completed",
            active_job_id: job.active_job_id,
            arguments: job.arguments,
            finished_at: job.finished_at,
            created_at: job.created_at
          )
        end
      end

      private_class_method def self.apply_class_name_filter(scope, filter)
        return scope if filter.blank?
        scope.merge(SolidQueue::Job.where("class_name LIKE ?", "%#{filter}%"))
      end

      private_class_method def self.count_scope(scope, filter: nil, queue: nil)
        scope = scope.merge(SolidQueue::Job.where(queue_name: queue)) if queue
        scope = apply_class_name_filter(scope, filter)
        scope.count
      end

      private_class_method def self.count_finished(filter: nil, queue: nil)
        scope = SolidQueue::Job.finished
        scope = scope.where(queue_name: queue) if queue
        scope = scope.where("class_name LIKE ?", "%#{filter}%") if filter.present?
        scope.count
      end
    end
  end
end
