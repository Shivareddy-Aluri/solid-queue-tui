class ScheduledCleanupJob < ApplicationJob
  queue_as :low_priority

  def perform(days_old = 30)
    sleep rand(0.1..0.3)
    Rails.logger.info "Cleaned up records older than #{days_old} days"
  end
end
