class SyncInventoryJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 1, key: ->(sku) { sku }

  def perform(sku)
    sleep rand(0.3..1.0)
  end
end
