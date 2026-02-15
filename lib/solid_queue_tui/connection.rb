# frozen_string_literal: true

require "active_record"

module SolidQueueTui
  class Connection
    def self.establish!(database_url: nil)
      url = database_url || ENV["DATABASE_URL"]

      if url
        ActiveRecord::Base.establish_connection(parse_url(url))
      elsif defined?(Rails) && Rails.application
        config = Rails.application.config.database_configuration
        queue_config = config["queue"] || config[Rails.env]
        ActiveRecord::Base.establish_connection(queue_config)
      else
        raise ConnectionError, <<~MSG
          No database connection configured.

          Either:
            1. Set DATABASE_URL environment variable
            2. Pass --database-url to sqtui
            3. Run inside a Rails application directory
        MSG
      end

      verify_solid_queue_tables!
    end

    # Parse a database URL into a connection hash.
    # Handles sqlite3 paths that ActiveRecord's URL parser can struggle with.
    def self.parse_url(url)
      if url.start_with?("sqlite3:")
        path = url.sub(%r{\Asqlite3:/*}, "")
        # Restore leading slash for absolute paths
        path = "/#{path}" if url.match?(%r{\Asqlite3:/})
        { adapter: "sqlite3", database: path }
      else
        url
      end
    end

    def self.verify_solid_queue_tables!
      conn = ActiveRecord::Base.connection
      required = %w[solid_queue_jobs solid_queue_ready_executions]
      missing = required.reject { |t| conn.table_exists?(t) }

      unless missing.empty?
        raise ConnectionError, "Missing Solid Queue tables: #{missing.join(', ')}. " \
                               "Is this a Solid Queue database?"
      end
    end

    class ConnectionError < StandardError; end
  end
end
