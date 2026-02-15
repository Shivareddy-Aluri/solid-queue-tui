# Seed script — creates a rich initial state in the queue database.
#
# Two phases:
#   Phase 1: Direct DB inserts for historical data (completed jobs, past failures, etc.)
#            This gives an immediately rich dashboard without running workers.
#   Phase 2: Active Job enqueues for fresh jobs that workers can process live.
#
# Run with: bin/rails db:seed

require "securerandom"
require "json"

puts "Seeding Solid Queue data..."
puts ""

now = Time.now.utc
conn = SolidQueue::Record.connection

# ═══════════════════════════════════════════════════════════════════════════
# Phase 1: Direct inserts for historical data
# ═══════════════════════════════════════════════════════════════════════════

puts "  Phase 1: Inserting historical data directly..."

JOB_CLASSES = {
  "default"      => %w[ProcessOrderJob SyncInventoryJob],
  "mailers"      => %w[SendNotificationJob],
  "urgent"       => %w[UrgentAlertJob],
  "reports"      => %w[GenerateReportJob DataExportJob],
  "low_priority" => %w[ScheduledCleanupJob WarmCacheJob]
}.freeze

ERRORS = [
  { exception_class: "NoMethodError",
    message: "undefined method `email' for nil:NilClass",
    backtrace: ["app/jobs/send_notification_job.rb:8:in `perform'",
                "activejob/lib/active_job/execution.rb:53:in `perform_now'"] },
  { exception_class: "ActiveRecord::RecordNotFound",
    message: "Couldn't find User with 'id'=99999",
    backtrace: ["activerecord/lib/active_record/core.rb:284:in `find'",
                "app/jobs/process_order_job.rb:8:in `perform'"] },
  { exception_class: "Timeout::Error",
    message: "execution expired after 30s — external API at api.stripe.com did not respond",
    backtrace: ["net/http.rb:987:in `connect'",
                "lib/payments/stripe_client.rb:45:in `charge'",
                "app/jobs/process_order_job.rb:12:in `perform'"] },
  { exception_class: "ArgumentError",
    message: "wrong number of arguments (given 3, expected 1..2)",
    backtrace: ["app/services/invoice_generator.rb:28:in `generate'",
                "app/jobs/generate_report_job.rb:11:in `perform'"] },
  { exception_class: "RuntimeError",
    message: "External service unavailable: 503 Service Temporarily Unavailable",
    backtrace: ["lib/http_client.rb:22:in `post'",
                "app/jobs/sync_inventory_job.rb:15:in `perform'"] },
  { exception_class: "IOError",
    message: "closed stream — connection to Redis lost",
    backtrace: ["redis/lib/redis/client.rb:368:in `establish_connection'",
                "app/jobs/warm_cache_job.rb:10:in `perform'"] }
].freeze

def make_arguments(klass)
  args = case klass
         when "ProcessOrderJob"      then [rand(1000..9999)]
         when "SyncInventoryJob"     then ["SKU-#{rand(1..50).to_s.rjust(3, '0')}"]
         when "SendNotificationJob"  then [rand(1..500), "Notification message"]
         when "UrgentAlertJob"       then ["security", "Alert triggered"]
         when "GenerateReportJob"    then ["sales", "2026-01-01..2026-02-14"]
         when "DataExportJob"        then ["csv", rand(1..100)]
         when "ScheduledCleanupJob"  then [30]
         when "WarmCacheJob"         then ["page:home"]
         when "FailingJob"           then [rand(0..5)]
         else [42]
         end

  {
    job_class: klass,
    job_id: SecureRandom.uuid,
    provider_job_id: nil,
    queue_name: nil,
    priority: nil,
    arguments: args,
    executions: 0,
    exception_executions: {},
    locale: "en",
    timezone: "UTC",
    enqueued_at: Time.now.utc.iso8601
  }.to_json
end

job_id = 0

# ── Completed jobs (120 historical finished jobs) ──────────────────────
puts "    120 completed jobs..."
120.times do
  job_id += 1
  queue = JOB_CLASSES.keys.sample
  klass = JOB_CLASSES[queue].sample
  created = now - rand(1..72) * 3600 - rand(3600)
  finished = created + rand(1..120)

  conn.execute(<<~SQL)
    INSERT INTO solid_queue_jobs (id, queue_name, class_name, arguments, priority, active_job_id, finished_at, created_at, updated_at)
    VALUES (#{job_id}, '#{queue}', '#{klass}', '#{conn.quote_string(make_arguments(klass))}',
            #{rand(0..2)}, '#{SecureRandom.uuid}', '#{finished.iso8601}', '#{created.iso8601}', '#{created.iso8601}')
  SQL
end

# ── Failed jobs (8 with realistic errors) ──────────────────────────────
puts "    8 failed jobs with errors..."
8.times do |i|
  job_id += 1
  queue = JOB_CLASSES.keys.sample
  klass = JOB_CLASSES[queue].sample
  created = now - rand(300..7200)
  failed_at = created + rand(1..60)
  error = ERRORS[i % ERRORS.size]

  conn.execute(<<~SQL)
    INSERT INTO solid_queue_jobs (id, queue_name, class_name, arguments, priority, active_job_id, created_at, updated_at)
    VALUES (#{job_id}, '#{queue}', '#{klass}', '#{conn.quote_string(make_arguments(klass))}',
            #{rand(0..1)}, '#{SecureRandom.uuid}', '#{created.iso8601}', '#{created.iso8601}')
  SQL

  conn.execute(<<~SQL)
    INSERT INTO solid_queue_failed_executions (job_id, error, created_at)
    VALUES (#{job_id}, '#{conn.quote_string(error.to_json)}', '#{failed_at.iso8601}')
  SQL
end

# ═══════════════════════════════════════════════════════════════════════════
# Phase 2: Enqueue fresh jobs via Active Job (workers will process these)
# ═══════════════════════════════════════════════════════════════════════════

puts ""
puts "  Phase 2: Enqueuing fresh jobs via Active Job..."

puts "    20 ProcessOrderJobs..."
20.times { ProcessOrderJob.perform_later(rand(1000..9999)) }

puts "    15 SendNotificationJobs..."
15.times { SendNotificationJob.perform_later(rand(1..500), ["Welcome!", "Order shipped!", "Payment OK"].sample) }

puts "    8 UrgentAlertJobs..."
8.times { UrgentAlertJob.perform_later(%w[security payment system fraud].sample, "Alert at #{Time.now}") }

puts "    5 WarmCacheJobs..."
5.times { WarmCacheJob.perform_later("page:#{%w[home products users dashboard].sample}") }

puts "    10 GenerateReportJobs..."
10.times { GenerateReportJob.perform_later(%w[sales inventory users revenue].sample, "#{Date.today - rand(1..30)}..#{Date.today}") }

puts "    4 DataExportJobs..."
4.times { DataExportJob.perform_later(%w[csv json xlsx].sample, rand(1..100)) }

puts "    10 FailingJobs (will create more failures when workers run)..."
10.times { |i| FailingJob.perform_later(i % 6) }

puts "    12 SyncInventoryJobs (concurrency limited)..."
%w[SKU-001 SKU-002 SKU-003].each { |sku| 4.times { SyncInventoryJob.perform_later(sku) } }

puts "    15 ScheduledCleanupJobs (future)..."
15.times { ScheduledCleanupJob.set(wait: rand(5..120).minutes).perform_later(rand(7..90)) }

puts ""
puts "  ─────────────────────────────────────────────────────────"
puts "  Seed complete!"
puts ""
puts "  Historical data (immediate, no workers needed):"
puts "    120 completed jobs"
puts "    8 failed jobs with error details"
puts ""
puts "  Fresh jobs (need workers to process):"
puts "    84 ready + 15 scheduled + 12 concurrency-limited"
puts ""
puts "  Next steps:"
puts "    1. Start workers:  bin/jobs"
puts "    2. Launch TUI:     bin/tui"
puts "  ─────────────────────────────────────────────────────────"
