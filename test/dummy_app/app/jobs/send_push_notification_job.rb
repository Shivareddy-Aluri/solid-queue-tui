class SendPushNotificationJob < ApplicationJob
  queue_as :notifications

  def perform(user_id, title, body)
    sleep rand(0.05..0.15)
  end
end
