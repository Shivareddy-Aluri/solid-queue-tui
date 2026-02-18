class ProcessPaymentJob < ApplicationJob
  queue_as :billing

  def perform(invoice_id, amount_cents)
    sleep rand(0.2..0.6)
  end
end
