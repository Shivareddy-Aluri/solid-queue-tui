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

      RunningJob = Struct.new(
        :job_id, :class_name, :queue_name, :started_at,
        keyword_init: true
      )

      def self.fetch_running_jobs(process_id:)
        SolidQueue::ClaimedExecution
          .where(process_id: process_id)
          .joins(:job).includes(:job)
          .order(:created_at)
          .map do |ce|
            job = ce.job
            RunningJob.new(
              job_id: job.id,
              class_name: job.class_name,
              queue_name: job.queue_name,
              started_at: ce.created_at
            )
          end
      rescue => e
        []
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
