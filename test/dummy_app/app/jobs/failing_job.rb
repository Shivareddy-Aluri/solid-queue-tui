class FailingJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: 0, attempts: 1

  ERRORS = [
    -> { raise NoMethodError, "undefined method 'process!' for nil:NilClass" },
    -> { raise ActiveRecord::RecordNotFound, "Couldn't find User with 'id'=999" },
    -> { raise Timeout::Error, "execution expired after 30s" },
    -> { raise ArgumentError, "invalid value for Integer(): \"abc\"" },
    -> { raise RuntimeError, "Payment gateway returned HTTP 503" },
    -> { raise IOError, "closed stream" }
  ].freeze

  def perform(scenario = nil)
    sleep rand(0.05..0.1)
    ERRORS.sample.call
  end
end
