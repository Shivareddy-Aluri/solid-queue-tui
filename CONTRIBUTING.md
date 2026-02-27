# Contributing to Solid Queue TUI

## Setup

The repo includes a dummy Rails app at `test/dummy_app/` for local development:

```bash
cd test/dummy_app
bundle install
bin/rails db:setup
```

## Running in dev mode

The `--dev` flag enables **hot-reload** — edit any file under `lib/` and the TUI picks up changes on the next keypress, no restart needed:

```bash
cd test/dummy_app
bundle exec qtop --dev
```

## Seeding test data

A seed script is included to populate large datasets for performance testing:

```bash
cd test/dummy_app
bin/rails db:seed
```

This creates **100,000 rows per view** (failed, scheduled, in-progress, blocked, finished) plus 5 recurring tasks. Override the count with `SEED_COUNT`:

```bash
SEED_COUNT=1000000 bin/rails db:seed
```

To wipe everything and re-seed from scratch:

```bash
bin/rails db:seed:replant
```

## Logging & debugging

The TUI is a separate process from your Rails server, but it boots the full Rails environment (`config/environment.rb`) and shares the same database. ActiveRecord queries are logged to the Rails log file automatically.

**Viewing SQL logs in real time:**

```bash
# In a separate terminal
tail -f test/dummy_app/log/development.log
```

Every query the TUI makes (list jobs, retry, discard, pause queue, etc.) appears here — just like requests in your Rails server log.

**Adding debug output:**

Since the TUI owns stdout, you can't use `puts` for debugging. Instead, write to the Rails logger:

```ruby
Rails.logger.info("DEBUG: selected_row=#{@selected_row}, jobs=#{@jobs.size}")
```

Then watch the log file with `tail -f`. You can also set `DEBUG=1` for hot-reload error messages:

```bash
DEBUG=1 bundle exec qtop --dev
```