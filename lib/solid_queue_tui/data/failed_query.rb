# frozen_string_literal: true

module SolidQueueTui
  module Data
    class FailedQuery
      FailedJob = Struct.new(
        :id, :job_id, :queue_name, :class_name, :priority,
        :error_class, :error_message, :backtrace,
        :active_job_id, :arguments, :failed_at, :created_at,
        keyword_init: true
      )

      def self.fetch(filter: nil, limit: 200)
        conn = ActiveRecord::Base.connection

        sql = <<~SQL
          SELECT
            fe.id,
            fe.job_id,
            j.queue_name,
            j.class_name,
            j.priority,
            j.active_job_id,
            j.arguments,
            j.created_at AS job_created_at,
            fe.error,
            fe.created_at AS failed_at
          FROM solid_queue_failed_executions fe
          JOIN solid_queue_jobs j ON j.id = fe.job_id
        SQL

        if filter && !filter.empty?
          sql += " WHERE j.class_name LIKE #{conn.quote("%#{filter}%")}"
        end

        sql += " ORDER BY fe.created_at DESC LIMIT #{limit.to_i}"

        rows = conn.select_all(sql)
        rows.map do |row|
          error = parse_json(row["error"])

          FailedJob.new(
            id: row["id"].to_i,
            job_id: row["job_id"].to_i,
            queue_name: row["queue_name"],
            class_name: row["class_name"],
            priority: row["priority"].to_i,
            error_class: error["exception_class"] || error["class"] || "Unknown",
            error_message: error["message"] || "No message",
            backtrace: error["backtrace"] || [],
            active_job_id: row["active_job_id"],
            arguments: parse_json(row["arguments"]),
            failed_at: parse_time(row["failed_at"]),
            created_at: parse_time(row["job_created_at"])
          )
        end
      rescue => e
        []
      end

      def self.fetch_one(id)
        conn = ActiveRecord::Base.connection

        row = conn.select_one(<<~SQL)
          SELECT
            fe.id,
            fe.job_id,
            j.queue_name,
            j.class_name,
            j.priority,
            j.active_job_id,
            j.arguments,
            j.created_at AS job_created_at,
            fe.error,
            fe.created_at AS failed_at
          FROM solid_queue_failed_executions fe
          JOIN solid_queue_jobs j ON j.id = fe.job_id
          WHERE fe.id = #{conn.quote(id.to_i)}
        SQL

        return nil unless row

        error = parse_json(row["error"])

        FailedJob.new(
          id: row["id"].to_i,
          job_id: row["job_id"].to_i,
          queue_name: row["queue_name"],
          class_name: row["class_name"],
          priority: row["priority"].to_i,
          error_class: error["exception_class"] || error["class"] || "Unknown",
          error_message: error["message"] || "No message",
          backtrace: error["backtrace"] || [],
          active_job_id: row["active_job_id"],
          arguments: parse_json(row["arguments"]),
          failed_at: parse_time(row["failed_at"]),
          created_at: parse_time(row["job_created_at"])
        )
      rescue => e
        nil
      end

      private_class_method def self.parse_json(value)
        return {} if value.nil?
        value.is_a?(Hash) || value.is_a?(Array) ? value : JSON.parse(value.to_s)
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
