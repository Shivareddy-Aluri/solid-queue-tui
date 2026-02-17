class ProcessOrderJob < ApplicationJob
  queue_as :default

  def perform(order_id)
    sleep rand(0.1..0.5)
  end
end
