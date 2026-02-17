# frozen_string_literal: true

module SolidQueueTui
  module Data
    class Stats
      attr_reader :ready, :claimed, :failed, :scheduled, :blocked,
                  :total_jobs, :completed_jobs, :process_count,
                  :processes_by_kind

      def initialize(data)
        @ready = data[:ready]
        @claimed = data[:claimed]
        @failed = data[:failed]
        @scheduled = data[:scheduled]
        @blocked = data[:blocked]
        @total_jobs = data[:total_jobs]
        @completed_jobs = data[:completed_jobs]
        @process_count = data[:process_count]
        @processes_by_kind = data[:processes_by_kind]
      end

      def self.fetch
        new(
          ready: SolidQueue::ReadyExecution.count,
          claimed: SolidQueue::ClaimedExecution.count,
          failed: SolidQueue::FailedExecution.count,
          scheduled: SolidQueue::ScheduledExecution.count,
          blocked: SolidQueue::BlockedExecution.count,
          total_jobs: SolidQueue::Job.count,
          completed_jobs: SolidQueue::Job.finished.count,
          process_count: SolidQueue::Process.count,
          processes_by_kind: SolidQueue::Process.group(:kind).count
        )
      rescue => e
        empty(error: e.message)
      end

      def self.empty(error: nil)
        new(
          ready: 0, claimed: 0, failed: 0, scheduled: 0, blocked: 0,
          total_jobs: 0, completed_jobs: 0, process_count: 0,
          processes_by_kind: {}
        )
      end
    end
  end
end
