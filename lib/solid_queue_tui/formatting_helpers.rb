# frozen_string_literal: true

module SolidQueueTui
  module FormattingHelpers
    def time_ago(time)
      return "n/a" unless time
      seconds = (Time.now.utc - time).to_i
      case seconds
      when 0..59       then "#{seconds}s ago"
      when 60..3599    then "#{seconds / 60}m ago"
      when 3600..86399 then "#{seconds / 3600}h ago"
      else "#{seconds / 86400}d ago"
      end
    end

    def format_time(time)
      return "n/a" unless time
      time.strftime("%Y-%m-%d %H:%M:%S")
    end

    def format_duration(seconds)
      return "n/a" unless seconds
      seconds = seconds.to_i
      if seconds < 1
        "<1s"
      elsif seconds < 60
        "#{seconds}s"
      elsif seconds < 3600
        "#{seconds / 60}m #{seconds % 60}s"
      elsif seconds < 86400
        "#{seconds / 3600}h #{(seconds % 3600) / 60}m"
      else
        "#{seconds / 86400}d #{(seconds % 86400) / 3600}h"
      end
    end

    def format_number(n)
      return "0" if n.nil? || n == 0
      n.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    end

    def truncate(str, max)
      return "" unless str
      str.length > max ? "#{str[0...max - 3]}..." : str
    end

    def humanize_duration(seconds)
      case seconds.abs
      when 0..59       then "#{seconds.abs}s"
      when 60..3599    then "#{seconds.abs / 60}m"
      when 3600..86399 then "#{seconds.abs / 3600}h"
      else "#{seconds.abs / 86400}d"
      end
    end

    def time_until(time)
      return "n/a" unless time
      seconds = (time - Time.now.utc).to_i
      return "now" if seconds <= 0
      "in #{humanize_duration(seconds)}"
    end
  end
end
