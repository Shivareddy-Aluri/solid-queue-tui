# frozen_string_literal: true

module SolidQueueTui
  module Actions
    class EnqueueRecurringTask
      def self.call(task_key)
        task = SolidQueue::RecurringTask.find_by!(key: task_key)
        task.enqueue(at: Time.now)
      end
    end
  end
end
