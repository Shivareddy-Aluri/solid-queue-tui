class WarmCacheJob < ApplicationJob
  queue_as :low_priority

  def perform(cache_key)
    sleep rand(0.1..0.3)
    Rails.logger.info "Warmed cache for #{cache_key}"
  end
end
