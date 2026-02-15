# frozen_string_literal: true

module SolidQueueTui
  module Data
    class QueuesQuery
      QueueInfo = Struct.new(
        :name, :size, :paused,
        keyword_init: true
      )

      def self.fetch
        conn = ActiveRecord::Base.connection

        queue_sizes = conn.select_rows(
          "SELECT queue_name, COUNT(*) FROM solid_queue_ready_executions GROUP BY queue_name ORDER BY queue_name"
        ).to_h { |name, count| [name, count.to_i] }

        all_queues = conn.select_values(
          "SELECT DISTINCT queue_name FROM solid_queue_jobs WHERE queue_name IS NOT NULL ORDER BY queue_name"
        )

        paused = conn.select_values("SELECT queue_name FROM solid_queue_pauses")

        all_queues.map do |name|
          QueueInfo.new(
            name: name,
            size: queue_sizes[name] || 0,
            paused: paused.include?(name)
          )
        end
      rescue => e
        []
      end
    end
  end
end
