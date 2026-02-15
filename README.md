# Solid Queue TUI

> **Beta** — This project is under active development.

A terminal UI dashboard for [Solid Queue](https://github.com/rails/solid_queue), built with [ratatui_ruby](https://www.ratatui-ruby.dev/). Monitor and manage your Solid Queue jobs without leaving the terminal.

![Solid Queue TUI Demo](screenshots/demo.gif)

## Installation

Add to your Gemfile:

```ruby
gem "solid_queue_tui"
```

Then:

```bash
bundle install
```

## Usage

Create `config/solid_tui.yml` in your Rails app:

```yaml
database_url: postgres://localhost/myapp_queue
refresh: 2
```

Then run:

```bash
bundle exec sqtui
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

## Requirements

- Ruby 3.2+
- Solid Queue
- One of: `sqlite3`, `pg`, `mysql2`

## License

MIT
