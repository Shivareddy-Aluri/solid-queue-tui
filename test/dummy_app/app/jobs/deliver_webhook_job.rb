class DeliverWebhookJob < ApplicationJob
  queue_as :webhooks

  def perform(endpoint_url, payload = {})
    sleep rand(0.1..0.4)
  end
end
