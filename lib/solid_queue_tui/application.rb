# frozen_string_literal: true

require "ratatui_ruby"
require "json"

module SolidQueueTui
  class Application
    VIEW_DASHBOARD   = 0
    VIEW_QUEUES      = 1
    VIEW_FAILED      = 2
    VIEW_IN_PROGRESS = 3
    VIEW_BLOCKED     = 4
    VIEW_SCHEDULED   = 5
    VIEW_FINISHED    = 6
    VIEW_WORKERS     = 7

    VIEW_COUNT = 8

    COMMAND_MAP = {
      "dashboard"   => VIEW_DASHBOARD,
      "queues"      => VIEW_QUEUES,
      "failed"      => VIEW_FAILED,
      "in_progress" => VIEW_IN_PROGRESS,
      "inprogress"  => VIEW_IN_PROGRESS,
      "blocked"     => VIEW_BLOCKED,
      "scheduled"   => VIEW_SCHEDULED,
      "finished"    => VIEW_FINISHED,
      "workers"     => VIEW_WORKERS
    }.freeze

    def initialize(database_url: nil, refresh_interval: 2, dev: false)
      @database_url = database_url
      @refresh_interval = refresh_interval
      @current_view = VIEW_DASHBOARD
      @last_refresh = Time.at(0)
      @stats = Data::Stats.empty
      @show_help = false
      @command_mode = false
      @command_input = ""
      @command_error = nil
      @dev = dev
    end

    def run
      Connection.establish!(database_url: @database_url)
      setup_dev_reloader! if @dev

      RatatuiRuby.run do |tui|
        @tui = tui
        init_views
        refresh_data!

        loop do
          hot_reload! if @dev
          render
          event = @tui.poll_event
          refresh_data_if_needed
          break if handle_input(event)
        end
      end
    end

    private

    def init_views
      @views = {
        VIEW_DASHBOARD   => Views::DashboardView.new(@tui),
        VIEW_QUEUES      => Views::QueuesView.new(@tui),
        VIEW_FAILED      => Views::FailedView.new(@tui),
        VIEW_IN_PROGRESS => Views::InProgressView.new(@tui),
        VIEW_BLOCKED     => Views::BlockedView.new(@tui),
        VIEW_SCHEDULED   => Views::ScheduledView.new(@tui),
        VIEW_FINISHED    => Views::FinishedView.new(@tui),
        VIEW_WORKERS     => Views::ProcessesView.new(@tui)
      }
      @job_detail = Views::JobDetailView.new(@tui)
    end

    def render
      @tui.draw do |frame|
        if @show_help
          render_help_overlay(frame, frame.area)
          return
        end

        # Layout: header (6) | content (fill) | help_bar (1)
        header_area, content_area, help_area = @tui.layout_split(
          frame.area,
          direction: :vertical,
          constraints: [
            @tui.constraint_length(6),
            @tui.constraint_fill(1),
            @tui.constraint_length(1)
          ]
        )

        # Header
        Components::Header.new(
          @tui,
          current_view: @current_view
        ).render(frame, header_area)

        # Content — current view or detail overlay
        if @job_detail.active?
          @job_detail.render(frame, content_area)
        else
          current_view.render(frame, content_area)
        end

        # Help bar or command input
        if @command_mode
          render_command_bar(frame, help_area)
        else
          active_view = @job_detail.active? ? @job_detail : current_view
          Components::HelpBar.new(
            @tui,
            breadcrumb: active_view.breadcrumb,
            bindings: active_view.bindings,
            status: status_message
          ).render(frame, help_area)
        end
      end
    end

    def handle_input(event)
      return false unless event

      # Job detail overlay gets priority
      if @job_detail.active?
        result = @job_detail.handle_input(event)
        refresh_data! if result == :refresh
        return false
      end

      # Help overlay
      if @show_help
        case event
        in { type: :key, code: "esc" } | { type: :key, code: "?" } | { type: :key, code: "q" }
          @show_help = false
        else
          nil
        end
        return false
      end

      # If view is in a modal state (filter, confirm), it gets all input
      if current_view.respond_to?(:capturing_input?) && current_view.capturing_input?
        result = current_view.handle_input(event)
        refresh_data! if result == :refresh
        return false
      end

      # Command mode input
      if @command_mode
        handle_command_input(event)
        return false
      end

      # Global keybindings
      case event
      in { type: :key, code: "q" }
        return true
      in { type: :key, code: "c", modifiers: ["ctrl"] }
        return true
      in { type: :key, code: "esc" }
        switch_view(VIEW_DASHBOARD) if @current_view != VIEW_DASHBOARD
        return false
      in { type: :key, code: "r" }
        refresh_data!
        return false
      in { type: :key, code: "?" }
        @show_help = true
        return false
      in { type: :key, code: "1" }
        switch_view(VIEW_DASHBOARD)
        return false
      in { type: :key, code: "2" }
        switch_view(VIEW_QUEUES)
        return false
      in { type: :key, code: "3" }
        switch_view(VIEW_FAILED)
        return false
      in { type: :key, code: "4" }
        switch_view(VIEW_IN_PROGRESS)
        return false
      in { type: :key, code: "5" }
        switch_view(VIEW_BLOCKED)
        return false
      in { type: :key, code: "6" }
        switch_view(VIEW_SCHEDULED)
        return false
      in { type: :key, code: "7" }
        switch_view(VIEW_FINISHED)
        return false
      in { type: :key, code: "8" }
        switch_view(VIEW_WORKERS)
        return false
      in { type: :key, code: "tab" }
        switch_view((@current_view + 1) % VIEW_COUNT)
        return false
      in { type: :key, code: "enter" }
        open_detail
        return false
      in { type: :key, code: ":" }
        @command_mode = true
        @command_input = ""
        @command_error = nil
        return false
      else
        nil
      end

      # Pass to current view
      result = current_view.handle_input(event)
      refresh_data! if result == :refresh

      false
    end

    def current_view
      @views[@current_view]
    end

    def switch_view(index)
      @current_view = index
      refresh_data!
    end

    def open_detail
      item = current_view.selected_item
      return unless item

      case @current_view
      when VIEW_FAILED
        failed_job = Data::FailedQuery.fetch_one(item.id) if item.respond_to?(:id)
        @job_detail.show(failed_job: failed_job || item)
      when VIEW_IN_PROGRESS, VIEW_BLOCKED, VIEW_SCHEDULED, VIEW_FINISHED
        @job_detail.show(job: item) if item.respond_to?(:id)
      end
    end

    def refresh_data_if_needed
      return if Time.now - @last_refresh < @refresh_interval
      refresh_data!
    end

    def refresh_data!
      @stats = Data::Stats.fetch
      @last_refresh = Time.now

      case @current_view
      when VIEW_DASHBOARD
        current_view.update(stats: @stats)
      when VIEW_QUEUES
        queues = Data::QueuesQuery.fetch
        current_view.update(queues: queues)
      when VIEW_FAILED
        filter = current_view.filter
        failed_jobs = Data::FailedQuery.fetch(filter: filter)
        current_view.update(failed_jobs: failed_jobs)
      when VIEW_IN_PROGRESS
        jobs = Data::JobsQuery.fetch(status: "claimed")
        current_view.update(jobs: jobs)
      when VIEW_BLOCKED
        jobs = Data::JobsQuery.fetch(status: "blocked")
        current_view.update(jobs: jobs)
      when VIEW_SCHEDULED
        jobs = Data::JobsQuery.fetch(status: "scheduled")
        current_view.update(jobs: jobs)
      when VIEW_FINISHED
        filter = current_view.respond_to?(:filter) ? current_view.filter : nil
        jobs = Data::JobsQuery.fetch(status: "completed", filter: filter)
        current_view.update(jobs: jobs)
      when VIEW_WORKERS
        processes = Data::ProcessesQuery.fetch
        current_view.update(processes: processes)
      end
    rescue => e
      # Silently handle refresh errors to keep TUI responsive
    end

    def setup_dev_reloader!
      lib_dir = File.expand_path("../..", __FILE__)
      @reloader = DevReloader.new(lib_dir)
    end

    # Check for file changes and re-instantiate views if code was reloaded.
    def hot_reload!
      return unless @reloader
      if @reloader.check!
        init_views
        refresh_data!
      end
    end

    def handle_command_input(event)
      case event
      in { type: :key, code: "enter" }
        execute_command(@command_input.strip)
        @command_mode = false
        @command_input = ""
      in { type: :key, code: "esc" }
        @command_mode = false
        @command_input = ""
        @command_error = nil
      in { type: :key, code: "backspace" }
        @command_input = @command_input[0...-1]
      in { type: :key, code: /\A.\z/ => char }
        @command_input += char
      else
        nil
      end
    end

    def execute_command(input)
      return if input.empty?

      # Exact match first
      if COMMAND_MAP.key?(input)
        switch_view(COMMAND_MAP[input])
        return
      end

      # Prefix match
      matches = COMMAND_MAP.keys.select { |cmd| cmd.start_with?(input) }
      if matches.size == 1
        switch_view(COMMAND_MAP[matches.first])
      end
    end

    def render_command_bar(frame, area)
      # Show completions as hint
      input = @command_input.strip
      hint = if input.empty?
               COMMAND_MAP.keys.uniq { |k| COMMAND_MAP[k] }.join("  ")
             else
               matches = COMMAND_MAP.keys.select { |cmd| cmd.start_with?(input) }
               matches.empty? ? "no match" : matches.join("  ")
             end

      frame.render_widget(
        @tui.paragraph(
          text: @tui.text_line(spans: [
            @tui.text_span(content: ":", style: @tui.style(fg: :cyan, modifiers: [:bold])),
            @tui.text_span(content: @command_input, style: @tui.style(fg: :white)),
            @tui.text_span(content: "\u2588", style: @tui.style(fg: :white)),
            @tui.text_span(content: "  #{hint}", style: @tui.style(fg: :dark_gray))
          ]),
          style: @tui.style(fg: :white)
        ),
        area
      )
    end

    def status_message
      elapsed = (Time.now - @last_refresh).to_i
      "Last refresh: #{elapsed}s ago"
    end

    def render_help_overlay(frame, area)
      help_text = [
        @tui.text_line(spans: [
          @tui.text_span(content: "  SOLID QUEUE TUI — KEYBOARD SHORTCUTS", style: @tui.style(fg: :yellow, modifiers: [:bold]))
        ]),
        empty_line,
        help_section("Navigation"),
        help_line("1-8", "Switch between views"),
        help_line("Tab", "Next view"),
        help_line(":", "Command mode (:queues, :failed, ...)"),
        help_line("Esc", "Back to Dashboard"),
        help_line("j / Up", "Move selection up"),
        help_line("k / Down", "Move selection down"),
        help_line("g", "Jump to top"),
        help_line("G", "Jump to bottom"),
        help_line("Enter", "View details"),
        empty_line,
        help_section("Actions"),
        help_line("r", "Refresh data"),
        help_line("/", "Filter by class name"),
        help_line("R", "Retry failed job (in Failed view)"),
        help_line("D", "Discard failed job (in Failed view)"),
        help_line("A", "Retry all failed jobs"),
        empty_line,
        help_section("Views"),
        help_line("1", "Dashboard — Overview with stats"),
        help_line("2", "Queues — Per-queue breakdown"),
        help_line("3", "Failed — Failed jobs with errors"),
        help_line("4", "In Progress — Currently processing"),
        help_line("5", "Blocked — Concurrency-blocked jobs"),
        help_line("6", "Scheduled — Future scheduled jobs"),
        help_line("7", "Finished — Completed jobs"),
        help_line("8", "Workers — Active processes"),
        empty_line,
        help_section("General"),
        help_line("?", "Toggle this help"),
        help_line("q", "Quit"),
        help_line("Ctrl+C", "Force quit")
      ]

      frame.render_widget(
        @tui.paragraph(
          text: help_text,
          block: @tui.block(
            title: " Help ",
            title_style: @tui.style(fg: :cyan, modifiers: [:bold]),
            titles: [
              { content: " Press ? or Esc to close ",
                position: :bottom, alignment: :center }
            ],
            borders: [:all],
            border_type: :rounded,
            border_style: @tui.style(fg: :cyan),
            style: @tui.style(fg: :white)
          )
        ),
        area
      )
    end

    def help_section(title)
      @tui.text_line(spans: [
        @tui.text_span(content: "  ── #{title} ──", style: @tui.style(fg: :cyan, modifiers: [:bold]))
      ])
    end

    def help_line(key, desc)
      @tui.text_line(spans: [
        @tui.text_span(content: "    #{key.ljust(14)}", style: @tui.style(fg: :green, modifiers: [:bold])),
        @tui.text_span(content: desc, style: @tui.style(fg: :white))
      ])
    end

    def empty_line
      @tui.text_line(spans: [
        @tui.text_span(content: "", style: @tui.style(fg: :white))
      ])
    end
  end
end
