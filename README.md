# Solid Queue TUI

> **Beta** — This project is under active development.

A terminal UI dashboard for [Solid Queue](https://github.com/rails/solid_queue), built with [ratatui_ruby](https://www.ratatui-ruby.dev/). Monitor and manage your Solid Queue jobs without leaving the terminal.

<video src="https://github.com/user-attachments/assets/3fbcc79d-9e67-4f0b-87b1-bdb81c515fe7" controls width="100%"></video>

## Requirements

- A **Rails application** (7.1+) with [Solid Queue](https://github.com/rails/solid_queue) configured as the Active Job backend
- Ruby 3.2+

This gem is a Rails Railtie. It uses the host app's existing database connection and Solid Queue's ActiveRecord models directly — no separate database configuration is needed.

## Installation

Add to your Rails app's Gemfile:

```ruby
gem "solid_queue_tui"
```

Then:

```bash
bundle install
```

## Usage

Run from your **Rails application's root directory**:

```bash
bundle exec sqtui
```

The TUI boots your Rails environment (via `config/environment.rb`), connects to the same database your app uses, and queries Solid Queue tables through its ActiveRecord models.

You can also launch via a rake task:

```bash
bundle exec rake solid_queue_tui:start
```

### Configuration

The refresh interval defaults to 2 seconds. You can customize it in an initializer:

```ruby
# config/initializers/solid_queue_tui.rb
SolidQueueTui.refresh_interval = 5
```

## Views

Press `1`-`8` to switch between views:

| Key | View | Description |
|-----|------|-------------|
| `1` | Dashboard | Overview with job counts and process info |
| `2` | Queues | Per-queue breakdown with sizes |
| `3` | Failed | Failed jobs — retry or discard |
| `4` | In Progress | Jobs currently being processed |
| `5` | Blocked | Jobs blocked by concurrency limits |
| `6` | Scheduled | Jobs scheduled for future execution |
| `7` | Finished | Completed jobs |
| `8` | Workers | Active worker processes |

## Key Bindings

| Key | Action |
|-----|--------|
| `j` / `k` | Navigate up / down |
| `Enter` | View job details |
| `/` | Filter by class name |
| `R` | Retry failed job |
| `D` | Discard failed job |
| `Esc` | Back to Dashboard |
| `r` | Refresh |
| `q` | Quit |

## License

MIT
