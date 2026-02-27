# frozen_string_literal: true

require "optparse"

module SolidQueueTui
  class CLI
    def self.run(args)
      options = parse_options(args)
      Application.new(**options).run
    rescue Interrupt
      exit 0
    end

    def self.parse_options(args)
      options = {}

      OptionParser.new do |opts|
        opts.banner = "Usage: qtop [options]"
        opts.separator ""
        opts.separator "Options:"

        opts.on("--dev", "Enable hot-reload (development only)") do
          unless defined?(Rails) && Rails.env.development?
            $stderr.puts "Error: --dev is only allowed in the development environment."
            exit 1
          end
          options[:dev] = true
        end

        opts.on("--page-size N", Integer, "Number of rows per page (default: #{SolidQueueTui.page_size})") do |n|
          SolidQueueTui.page_size = n
        end

        opts.on("--refresh-interval N", Integer, "Refresh interval in seconds (default: #{SolidQueueTui.refresh_interval})") do |n|
          SolidQueueTui.refresh_interval = n
        end

        opts.on("-v", "--version", "Show version") do
          puts "qtop v#{SolidQueueTui::VERSION}"
          exit
        end

        opts.on("-h", "--help", "Show this help") do
          puts opts
          puts ""
          puts "Run from your Rails app root directory."
          puts "Requires solid_queue_tui in your Gemfile and Solid Queue configured."
          exit
        end
      end.parse!(args)

      options
    end
  end
end
