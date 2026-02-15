class SendNotificationJob < ApplicationJob
  queue_as :mailers

  def perform(user_id, message)
    sleep rand(0.1..0.3)
    Rails.logger.info "Notification sent to user ##{user_id}: #{message}"
  end
end
