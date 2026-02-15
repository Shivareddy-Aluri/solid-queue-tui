class FailingJob < ApplicationJob
  queue_as :default

  # No retry_on — errors go straight to solid_queue_failed_executions

  ERRORS = [
    -> { raise NoMethodError, "undefined method `email' for nil:NilClass" },
    -> { raise ActiveRecord::RecordNotFound, "Couldn't find User with 'id'=99999" },
    -> { raise Timeout::Error, "execution expired after 30s" },
    -> { raise ArgumentError, "wrong number of arguments (given 3, expected 1..2)" },
    -> { raise RuntimeError, "External service unavailable: 503 Service Temporarily Unavailable" },
    -> { raise IOError, "closed stream — connection to Redis lost" }
  ].freeze

  def perform(error_index = nil)
    idx = error_index || rand(0...ERRORS.size)
    ERRORS[idx].call
  end
end
