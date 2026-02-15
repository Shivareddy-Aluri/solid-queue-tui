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
        conn = ActiveRecord::Base.connection

        rows = conn.select_all(
          "SELECT id, kind, pid, hostname, name, last_heartbeat_at, " \
          "supervisor_id, metadata, created_at " \
          "FROM solid_queue_processes ORDER BY kind, id"
        )

        rows.map do |row|
          metadata = parse_json(row["metadata"])

          Process.new(
            id: row["id"].to_i,
            kind: row["kind"],
            pid: row["pid"].to_i,
            hostname: row["hostname"],
            name: row["name"],
            last_heartbeat_at: parse_time(row["last_heartbeat_at"]),
            supervisor_id: row["supervisor_id"]&.to_i,
            metadata: metadata,
            created_at: parse_time(row["created_at"])
          )
        end
      rescue => e
        []
      end

      private_class_method def self.parse_json(value)
        return {} if value.nil?
        value.is_a?(Hash) ? value : JSON.parse(value.to_s)
      rescue JSON::ParserError
        {}
      end

      private_class_method def self.parse_time(value)
        return nil if value.nil?
        value.is_a?(Time) ? value : Time.parse(value.to_s)
      rescue
        nil
      end
    end
  end
end
