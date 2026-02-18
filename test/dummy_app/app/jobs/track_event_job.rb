class TrackEventJob < ApplicationJob
  queue_as :analytics

  def perform(event_name, properties = {})
    sleep rand(0.05..0.2)
  end
end
