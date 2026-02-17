class UrgentAlertJob < ApplicationJob
  queue_as :urgent

  def perform(alert_type, details = {})
    sleep rand(0.05..0.2)
  end
end
