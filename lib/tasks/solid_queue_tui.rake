# frozen_string_literal: true

namespace :solid_queue_tui do
  desc "Launch the Solid Queue TUI dashboard"
  task start: :environment do
    SolidQueueTui::CLI.run([])
  end
end
