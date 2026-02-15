require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"

Bundler.require(*Rails.groups)

module SolidQueueTestApp
  class Application < Rails::Application
    config.load_defaults 8.1
    config.autoload_lib(ignore: %w[assets tasks])

    # Use Solid Queue as the Active Job backend
    config.active_job.queue_adapter = :solid_queue

    # Don't generate system test files.
    config.generators.system_tests = nil
  end
end
