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
        opts.banner = "Usage: sqtui [options]"
        opts.separator ""
        opts.separator "Options:"

        opts.on("--dev", "Enable hot-reload (watches lib/ for changes)") do
          options[:dev] = true
        end

        opts.on("-v", "--version", "Show version") do
          puts "sqtui v#{SolidQueueTui::VERSION}"
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
