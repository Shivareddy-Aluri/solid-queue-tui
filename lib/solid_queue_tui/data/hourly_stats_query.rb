# frozen_string_literal: true

module SolidQueueTui
  module Data
    class HourlyStatsQuery
      Result = Struct.new(:data, :total, :peak, :avg, keyword_init: true)

      def self.enqueued_per_hour
        raw = SolidQueue::Job
          .where(created_at: 24.hours.ago..)
          .group(hour_sql(:created_at))
          .count
        build_result(raw)
      rescue => e
        empty_result
      end

      def self.processed_per_hour
        raw = SolidQueue::Job
          .where.not(finished_at: nil)
          .where(finished_at: 24.hours.ago..)
          .group(hour_sql(:finished_at))
          .count
        build_result(raw)
      rescue => e
        empty_result
      end

      def self.failed_per_hour
        raw = SolidQueue::FailedExecution
          .where(created_at: 24.hours.ago..)
          .group(hour_sql(:created_at))
          .count
        build_result(raw)
      rescue => e
        empty_result
      end

      def self.empty_result
        now = Time.now.utc
        data = (0..23).map { |i| (now - (23 - i) * 3600).strftime("%H").to_i }
        Result.new(data: data.map { 0 }, total: 0, peak: 0, avg: 0)
      end

      class << self
        private

        def hour_sql(column)
          if sqlite?
            Arel.sql("strftime('%Y-%m-%d %H:00:00', #{column})")
          else
            Arel.sql("DATE_TRUNC('hour', #{column})")
          end
        end

        def build_result(raw_hash)
          now = Time.now.utc

          lookup = {}
          raw_hash.each do |key, count|
            time = key.is_a?(String) ? Time.parse("#{key} UTC") : key
            lookup[time.strftime("%Y-%m-%d %H")] = count
          end

          # 24-slot array, oldest to newest — values only (for sparkline)
          data = (0..23).map do |i|
            hour_time = now - (23 - i) * 3600
            key = hour_time.strftime("%Y-%m-%d %H")
            lookup[key] || 0
          end

          total = data.sum
          peak = data.max || 0
          avg = total / 24

          Result.new(data: data, total: total, peak: peak, avg: avg)
        end

        def sqlite?
          SolidQueue::Job.connection.adapter_name.downcase.include?("sqlite")
        end
      end
    end
  end
end
