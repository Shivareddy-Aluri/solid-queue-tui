class DataExportJob < ApplicationJob
  queue_as :reports

  def perform(format, user_id)
    sleep rand(0.2..0.8)
    Rails.logger.info "Exported data in #{format} for user ##{user_id}"
  end
end
