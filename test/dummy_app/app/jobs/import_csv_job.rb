class ImportCsvJob < ApplicationJob
  queue_as :imports

  def perform(file_path, model_name)
    sleep rand(0.3..1.0)
  end
end
