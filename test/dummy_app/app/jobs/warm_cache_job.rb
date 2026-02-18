class WarmCacheJob < ApplicationJob
  queue_as :low_priority

  def perform
    sleep rand(0.1..0.3)
  end
end
