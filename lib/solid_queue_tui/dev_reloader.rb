# frozen_string_literal: true

module SolidQueueTui
  # Watches source files for changes and hot-reloads them using Kernel#load.
  # Only active when initialized — zero overhead in production.
  class DevReloader
    def initialize(watch_dir)
      @watch_dir = watch_dir
      @file_mtimes = {}
      snapshot_all!
    end

    # Returns true if any files changed and were reloaded.
    def check!
      changed = false

      ruby_files.each do |path|
        mtime = File.mtime(path)
        if @file_mtimes[path] != mtime
          @file_mtimes[path] = mtime
          begin
            suppress_warnings { load(path) }
            changed = true
          rescue SyntaxError, StandardError => e
            # Don't crash the TUI on a syntax error mid-edit.
            # The old code stays loaded — user just fixes and saves again.
            $stderr.puts "[reload] Error loading #{File.basename(path)}: #{e.message}" if ENV["DEBUG"]
          end
        end
      end

      changed
    end

    private

    def snapshot_all!
      ruby_files.each { |path| @file_mtimes[path] = File.mtime(path) }
    end

    def ruby_files
      Dir.glob(File.join(@watch_dir, "**", "*.rb"))
    end

    def suppress_warnings
      old_verbose = $VERBOSE
      $VERBOSE = nil
      yield
    ensure
      $VERBOSE = old_verbose
    end
  end
end
