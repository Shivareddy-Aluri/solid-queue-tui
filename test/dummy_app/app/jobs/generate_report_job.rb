class GenerateReportJob < ApplicationJob
  queue_as :reports

  def perform(report_type, date_range)
    sleep rand(0.2..0.8)
    Rails.logger.info "Generated #{report_type} report for #{date_range}"
  end
end
