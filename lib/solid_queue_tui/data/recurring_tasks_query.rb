# frozen_string_literal: true

module SolidQueueTui
  module Data
    class RecurringTasksQuery
      Task = Struct.new(
        :key, :class_name, :command, :schedule, :queue_name,
        :priority, :last_enqueued_at, :next_time,
        keyword_init: true
      )

      def self.fetch
        tasks = SolidQueue::RecurringTask.all.to_a
        return [] if tasks.empty?

        last_enqueued = SolidQueue::RecurringExecution
          .where(task_key: tasks.map(&:key))
          .group(:task_key)
          .maximum(:run_at)

        tasks.map do |task|
          Task.new(
            key: task.key,
            class_name: task.class_name,
            command: task.command,
            schedule: task.schedule,
            queue_name: task.queue_name,
            priority: task.priority,
            last_enqueued_at: last_enqueued[task.key],
            next_time: task.next_time
          )
        end
      end
    end
  end
end
