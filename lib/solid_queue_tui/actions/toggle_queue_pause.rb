# frozen_string_literal: true

module SolidQueueTui
  module Actions
    class ToggleQueuePause
      def self.call(queue_name)
        queue = SolidQueue::Queue.find_by_name(queue_name)
        if queue.paused?
          queue.resume
        else
          queue.pause
        end
        true
      rescue => e
        false
      end
    end
  end
end
