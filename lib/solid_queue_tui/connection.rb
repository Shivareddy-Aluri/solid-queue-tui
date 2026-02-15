# frozen_string_literal: true

require "active_record"
require "yaml"

module SolidQueueTui
  class Connection
    CONFIG_FILE = "config/solid_tui.yml"

    # Loads config, establishes the DB connection, and returns the parsed config hash.
    def self.establish!
      config = load_config

      url = config["database_url"]
      raise ConnectionError, <<~MSG unless url
        No database_url found in #{CONFIG_FILE}.

        Create #{CONFIG_FILE} with:
          database_url: postgres://user:pass@localhost/myapp_queue
          refresh: 2
      MSG

      ActiveRecord::Base.establish_connection(url)
      verify_solid_queue_tables!

      config
    end

    def self.load_config
      path = File.join(Dir.pwd, CONFIG_FILE)

      unless File.exist?(path)
        raise ConnectionError, <<~MSG
          Config file not found: #{CONFIG_FILE}

          Create #{CONFIG_FILE} with:
            database_url: postgres://user:pass@localhost/myapp_queue
            refresh: 2
        MSG
      end

      YAML.safe_load(File.read(path), permitted_classes: [Symbol]) || {}
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
