# frozen_string_literal: true

require_relative "lib/solid_queue_tui/version"

Gem::Specification.new do |spec|
  spec.name = "solid_queue_tui"
  spec.version = SolidQueueTui::VERSION
  spec.authors = ["Shiva Reddy"]
  spec.summary = "A K9s-inspired terminal UI for Solid Queue"
  spec.description = "Real-time terminal dashboard to monitor and manage Solid Queue jobs. " \
                     "Built with ratatui_ruby for native Rust rendering performance."
  spec.homepage = "https://github.com/shivareddyaluri/solid-queue-tui"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.files = Dir["lib/**/*", "exe/*", "LICENSE.txt"]
  spec.bindir = "exe"
  spec.executables = ["sqtui"]
  spec.require_paths = ["lib"]

  spec.add_dependency "ratatui_ruby", "~> 1.3"
  spec.add_dependency "activerecord", ">= 7.0"

  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "pg"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "minitest", "~> 5.0"
end
