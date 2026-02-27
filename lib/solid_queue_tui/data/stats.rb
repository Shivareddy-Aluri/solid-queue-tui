# frozen_string_literal: true

module SolidQueueTui
  module Data
    class Stats
      attr_reader :ready, :claimed, :failed, :scheduled, :blocked,
                  :total_jobs, :completed_jobs, :process_count,
                  :processes_by_kind,
                  :enqueued_per_hour, :processed_per_hour, :failed_per_hour,
                  :queue_depths

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
        @enqueued_per_hour = data[:enqueued_per_hour]
        @processed_per_hour = data[:processed_per_hour]
        @failed_per_hour = data[:failed_per_hour]
        @queue_depths = data[:queue_depths]
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
          processes_by_kind: SolidQueue::Process.group(:kind).count,
          enqueued_per_hour: HourlyStatsQuery.enqueued_per_hour,
          processed_per_hour: HourlyStatsQuery.processed_per_hour,
          failed_per_hour: HourlyStatsQuery.failed_per_hour,
          queue_depths: SolidQueue::ReadyExecution.group(:queue_name).count
        )
      rescue => e
        empty(error: e.message)
      end

      def self.empty(error: nil)
        new(
          ready: 0, claimed: 0, failed: 0, scheduled: 0, blocked: 0,
          total_jobs: 0, completed_jobs: 0, process_count: 0,
          processes_by_kind: {},
          enqueued_per_hour: nil, processed_per_hour: nil, failed_per_hour: nil,
          queue_depths: {}
        )
      end
    end
  end
end
