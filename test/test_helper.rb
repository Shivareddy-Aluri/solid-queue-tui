# frozen_string_literal: true

require "minitest/autorun"
require "time"

# Stub RatatuiRuby types used by concerns (Paginatable calls TableState.new in init_pagination)
module RatatuiRuby
  class TableState
    attr_reader :selected

    def initialize(_) = @selected = 0
    def select(idx) = @selected = idx
  end unless defined?(RatatuiRuby::TableState)

  class ListState
    def initialize(_) = nil
  end unless defined?(RatatuiRuby::ListState)
end

# Minimal SolidQueueTui module (avoids requiring the full gem and its ActiveRecord deps)
module SolidQueueTui
  @page_size = 100

  class << self
    attr_accessor :page_size
  end
end

# Require only the files under test — no DB, no TUI runtime
require_relative "../lib/solid_queue_tui/formatting_helpers"
require_relative "../lib/solid_queue_tui/data/processes_query"
require_relative "../lib/solid_queue_tui/views/concerns/confirmable"
require_relative "../lib/solid_queue_tui/views/concerns/filterable"
require_relative "../lib/solid_queue_tui/views/concerns/paginatable"
