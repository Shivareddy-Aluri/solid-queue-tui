# frozen_string_literal: true

module SolidQueueTui
  module Data
    class ProcessesQuery
      Process = Struct.new(
        :id, :kind, :pid, :hostname, :name, :last_heartbeat_at,
        :supervisor_id, :metadata, :created_at,
        keyword_init: true
      ) do
        def alive?(threshold: 60)
          return false unless last_heartbeat_at
          (Time.now.utc - last_heartbeat_at) < threshold
        end

        def uptime
          return nil unless created_at
          Time.now.utc - created_at
        end

        def queues
          return [] unless metadata.is_a?(Hash)
          metadata["queues"] || []
        end

        def thread_count
          return nil unless metadata.is_a?(Hash)
          metadata["threads"] || metadata["polling_interval"]
        end
      end

      def self.fetch
        SolidQueue::Process.where(kind: "Worker").order(:id).map do |proc|
          Process.new(
            id: proc.id,
            kind: proc.kind,
            pid: proc.pid,
            hostname: proc.hostname,
            name: proc.name,
            last_heartbeat_at: proc.last_heartbeat_at,
            supervisor_id: proc.supervisor_id,
            metadata: proc.metadata,
            created_at: proc.created_at
          )
        end
      rescue => e
        []
      end
    end
  end
end
