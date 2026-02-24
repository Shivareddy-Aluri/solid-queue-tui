# frozen_string_literal: true

module SolidQueueTui
  module Actions
    class EnqueueRecurringTask
      def self.call(task_key)
        task = SolidQueue::RecurringTask.find_by!(key: task_key)
        task.enqueue(at: Time.now)
        true
      rescue => e
        Rails.logger.tagged("SQTUI") { Rails.logger.error("EnqueueRecurringTask error: #{e.class}: #{e.message}") } if defined?(Rails) && Rails.logger
        false
      end
    end
  end
end
