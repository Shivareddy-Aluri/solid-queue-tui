# frozen_string_literal: true

module SolidQueueTui
  class Railtie < Rails::Railtie
    rake_tasks do
      load "tasks/solid_queue_tui.rake"
    end
  end
end
