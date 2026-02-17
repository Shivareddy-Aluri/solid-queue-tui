class GenerateReportJob < ApplicationJob
  queue_as :reports

  def perform(report_name, params = {})
    sleep rand(0.2..0.8)
  end
end
