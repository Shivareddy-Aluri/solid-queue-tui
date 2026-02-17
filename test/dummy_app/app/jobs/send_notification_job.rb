class SendNotificationJob < ApplicationJob
  queue_as :mailers

  def perform(user_id, message)
    sleep rand(0.1..0.3)
  end
end
