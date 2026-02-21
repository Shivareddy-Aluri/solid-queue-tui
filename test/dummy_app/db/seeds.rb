# Seed script to populate Solid Queue tables with large datasets for performance testing.
#
# Usage:
#   cd test/dummy_app
#   SEED_COUNT=1000000 bin/rails db:seed
#
# Default: 100,000 rows per view. Set SEED_COUNT to override.

COUNT = (ENV["SEED_COUNT"] || 100_000).to_i
BATCH = 5_000

JOB_CLASSES = %w[
  UserMailer::WelcomeEmail
  Reports::DailyDigestJob
  Payments::ProcessChargeJob
  Search::ReindexJob
  Analytics::TrackEventJob
  Notifications::PushNotifyJob
  Users::CleanupInactiveJob
  Orders::FulfillmentJob
  Imports::CsvProcessorJob
  Cache::WarmupJob
].freeze

QUEUES = %w[default mailers critical low background reports].freeze

puts "Seeding #{COUNT} rows per view (batch size: #{BATCH})..."

# Helper to build a job arguments JSON payload
def job_arguments
  '{"job_class":"SomeJob","arguments":[],"locale":"en"}'
end

# ── 1. Failed jobs ──────────────────────────────────────────────
puts "\n=> Failed jobs..."
(COUNT / BATCH).times do |batch_idx|
  jobs = BATCH.times.map do |i|
    n = batch_idx * BATCH + i
    {
      queue_name: QUEUES.sample,
      class_name: JOB_CLASSES.sample,
      arguments: job_arguments,
      priority: rand(0..3),
      active_job_id: SecureRandom.uuid,
      scheduled_at: nil,
      finished_at: nil,
      created_at: Time.now.utc - rand(1..72).hours,
      updated_at: Time.now.utc
    }
  end

  result = SolidQueue::Job.insert_all(jobs)
  job_ids = SolidQueue::Job.order(id: :desc).limit(BATCH).pluck(:id).reverse

  failed = job_ids.map do |jid|
    error = { exception_class: ["RuntimeError", "NoMethodError", "TimeoutError", "ActiveRecord::RecordNotFound"].sample,
              message: "Something went wrong processing the job",
              backtrace: ["app/jobs/some_job.rb:10:in `perform'"] }
    {
      job_id: jid,
      error: error,
      created_at: Time.now.utc - rand(1..48).hours
    }
  end
  SolidQueue::FailedExecution.insert_all(failed)

  print "\r  #{(batch_idx + 1) * BATCH} / #{COUNT}"
end
puts " ✓"

# ── 2. Scheduled jobs ──────────────────────────────────────────
puts "\n=> Scheduled jobs..."
(COUNT / BATCH).times do |batch_idx|
  jobs = BATCH.times.map do
    scheduled = Time.now.utc + rand(-2..72).hours
    {
      queue_name: QUEUES.sample,
      class_name: JOB_CLASSES.sample,
      arguments: job_arguments,
      priority: rand(0..3),
      active_job_id: SecureRandom.uuid,
      scheduled_at: scheduled,
      finished_at: nil,
      created_at: Time.now.utc - rand(1..24).hours,
      updated_at: Time.now.utc
    }
  end

  SolidQueue::Job.insert_all(jobs)
  job_ids = SolidQueue::Job.where(finished_at: nil)
                           .where.not(id: SolidQueue::FailedExecution.select(:job_id))
                           .where.not(id: SolidQueue::ScheduledExecution.select(:job_id))
                           .order(id: :desc).limit(BATCH).pluck(:id).reverse

  scheduled = job_ids.map do |jid|
    {
      job_id: jid,
      queue_name: QUEUES.sample,
      priority: rand(0..3),
      scheduled_at: Time.now.utc + rand(-2..72).hours,
      created_at: Time.now.utc
    }
  end
  SolidQueue::ScheduledExecution.insert_all(scheduled)

  print "\r  #{(batch_idx + 1) * BATCH} / #{COUNT}"
end
puts " ✓"

# ── 3. In-progress (claimed) jobs ──────────────────────────────
puts "\n=> In-progress (claimed) jobs..."

# Create a fake process for claimed executions
process = SolidQueue::Process.create!(
  kind: "Worker",
  last_heartbeat_at: Time.now.utc,
  pid: Process.pid,
  hostname: `hostname`.strip,
  name: "seed-worker-1",
  metadata: { queues: QUEUES.join(",") }.to_json
)

(COUNT / BATCH).times do |batch_idx|
  jobs = BATCH.times.map do
    {
      queue_name: QUEUES.sample,
      class_name: JOB_CLASSES.sample,
      arguments: job_arguments,
      priority: rand(0..3),
      active_job_id: SecureRandom.uuid,
      scheduled_at: nil,
      finished_at: nil,
      created_at: Time.now.utc - rand(1..60).minutes,
      updated_at: Time.now.utc
    }
  end

  SolidQueue::Job.insert_all(jobs)
  job_ids = SolidQueue::Job.where(finished_at: nil)
                           .where.not(id: SolidQueue::FailedExecution.select(:job_id))
                           .where.not(id: SolidQueue::ScheduledExecution.select(:job_id))
                           .where.not(id: SolidQueue::ClaimedExecution.select(:job_id))
                           .order(id: :desc).limit(BATCH).pluck(:id).reverse

  claimed = job_ids.map do |jid|
    {
      job_id: jid,
      process_id: process.id,
      created_at: Time.now.utc - rand(1..30).minutes
    }
  end
  SolidQueue::ClaimedExecution.insert_all(claimed)

  print "\r  #{(batch_idx + 1) * BATCH} / #{COUNT}"
end
puts " ✓"

# ── 4. Blocked jobs ────────────────────────────────────────────
puts "\n=> Blocked jobs..."
CONCURRENCY_KEYS = 10.times.map { |i| "lock:resource_#{i}" }.freeze

(COUNT / BATCH).times do |batch_idx|
  jobs = BATCH.times.map do
    {
      queue_name: QUEUES.sample,
      class_name: JOB_CLASSES.sample,
      arguments: job_arguments,
      priority: rand(0..3),
      active_job_id: SecureRandom.uuid,
      concurrency_key: CONCURRENCY_KEYS.sample,
      scheduled_at: nil,
      finished_at: nil,
      created_at: Time.now.utc - rand(1..120).minutes,
      updated_at: Time.now.utc
    }
  end

  SolidQueue::Job.insert_all(jobs)
  job_ids = SolidQueue::Job.where(finished_at: nil).where.not(concurrency_key: nil)
                           .where.not(id: SolidQueue::FailedExecution.select(:job_id))
                           .where.not(id: SolidQueue::ScheduledExecution.select(:job_id))
                           .where.not(id: SolidQueue::ClaimedExecution.select(:job_id))
                           .where.not(id: SolidQueue::BlockedExecution.select(:job_id))
                           .order(id: :desc).limit(BATCH).pluck(:id).reverse

  blocked = job_ids.map do |jid|
    job = SolidQueue::Job.find(jid)
    {
      job_id: jid,
      queue_name: job.queue_name,
      priority: job.priority,
      concurrency_key: job.concurrency_key,
      expires_at: Time.now.utc + 1.hour,
      created_at: Time.now.utc - rand(1..60).minutes
    }
  end
  SolidQueue::BlockedExecution.insert_all(blocked)

  print "\r  #{(batch_idx + 1) * BATCH} / #{COUNT}"
end
puts " ✓"

# ── 5. Finished jobs ───────────────────────────────────────────
puts "\n=> Finished jobs..."
(COUNT / BATCH).times do |batch_idx|
  jobs = BATCH.times.map do
    created = Time.now.utc - rand(1..168).hours
    finished = created + rand(1..300).seconds
    {
      queue_name: QUEUES.sample,
      class_name: JOB_CLASSES.sample,
      arguments: job_arguments,
      priority: rand(0..3),
      active_job_id: SecureRandom.uuid,
      scheduled_at: nil,
      finished_at: finished,
      created_at: created,
      updated_at: finished
    }
  end

  SolidQueue::Job.insert_all(jobs)
  print "\r  #{(batch_idx + 1) * BATCH} / #{COUNT}"
end
puts " ✓"

# ── 6. Recurring tasks ─────────────────────────────────────────
puts "\n=> Recurring tasks..."
recurring = [
  { key: "daily_digest", class_name: "Reports::DailyDigestJob", schedule: "0 8 * * *", queue_name: "reports", priority: 0, static: true },
  { key: "hourly_cleanup", class_name: "Users::CleanupInactiveJob", schedule: "0 * * * *", queue_name: "background", priority: 1, static: true },
  { key: "cache_warmup", class_name: "Cache::WarmupJob", schedule: "*/15 * * * *", queue_name: "default", priority: 0, static: true },
  { key: "analytics_flush", class_name: "Analytics::TrackEventJob", schedule: "*/5 * * * *", queue_name: "low", priority: 2, static: true },
  { key: "weekly_report", class_name: "Reports::DailyDigestJob", schedule: "0 9 * * 1", queue_name: "reports", priority: 0, static: true }
]
now = Time.now.utc
recurring.each { |r| r.merge!(created_at: now, updated_at: now) }
SolidQueue::RecurringTask.insert_all(recurring)
puts "  5 recurring tasks ✓"

puts "\nDone! Total jobs created: ~#{SolidQueue::Job.count}"
