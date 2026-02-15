class SyncInventoryJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 1, key: ->(sku) { "sync_inventory:#{sku}" }

  def perform(sku)
    sleep rand(0.1..0.5)
    Rails.logger.info "Synced inventory for SKU #{sku}"
  end
end
