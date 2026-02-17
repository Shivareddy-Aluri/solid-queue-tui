# frozen_string_literal: true

module SolidQueueTui
  module Actions
    class DiscardJob
      def self.call(failed_execution_id)
        fe = SolidQueue::FailedExecution.find(failed_execution_id)
        fe.discard
        true
      rescue ActiveRecord::RecordNotFound
        false
      rescue => e
        false
      end
    end
  end
end
