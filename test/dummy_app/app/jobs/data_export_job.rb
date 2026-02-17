class DataExportJob < ApplicationJob
  queue_as :reports

  def perform(export_type, user_id)
    sleep rand(0.2..0.8)
  end
end
