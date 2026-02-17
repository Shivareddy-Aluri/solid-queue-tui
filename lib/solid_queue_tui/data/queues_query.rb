# frozen_string_literal: true

module SolidQueueTui
  module Data
    class QueuesQuery
      QueueInfo = Struct.new(
        :name, :size, :paused,
        keyword_init: true
      )

      def self.fetch
        SolidQueue::Queue.all.map do |queue|
          QueueInfo.new(
            name: queue.name,
            size: queue.size,
            paused: queue.paused?
          )
        end
      rescue => e
        []
      end
    end
  end
end
