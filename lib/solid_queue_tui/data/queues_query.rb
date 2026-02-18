# frozen_string_literal: true

module SolidQueueTui
  module Data
    class QueuesQuery
      QueueInfo = Struct.new(
        :name, :size, :paused,
        keyword_init: true
      )

      def self.fetch
        queues = SolidQueue::Queue.all
        pauses = SolidQueue::Pause.where(queue_name: queues.map(&:name)).index_by(&:queue_name)

        queues.map do |queue|
          QueueInfo.new(
            name: queue.name,
            size: queue.size,
            paused: pauses[queue.name].present?
          )
        end
      rescue => e
        []
      end
    end
  end
end
