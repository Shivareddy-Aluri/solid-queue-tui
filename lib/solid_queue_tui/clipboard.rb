# frozen_string_literal: true

module SolidQueueTui
  module Clipboard
    # Copy text to the system clipboard.
    # Returns true on success, false on failure.
    def self.copy(text)
      command = clipboard_command
      return false unless command

      IO.popen(command, "w") { |io| io.write(text) }
      true
    rescue => e
      false
    end

    def self.available?
      !!clipboard_command
    end

    def self.clipboard_command
      @clipboard_command ||= detect_clipboard
    end

    def self.detect_clipboard
      if RUBY_PLATFORM.include?("darwin")
        "pbcopy"
      elsif ENV["WAYLAND_DISPLAY"] && system("which wl-copy > /dev/null 2>&1")
        "wl-copy"
      elsif system("which xclip > /dev/null 2>&1")
        "xclip -selection clipboard"
      elsif system("which xsel > /dev/null 2>&1")
        "xsel --clipboard --input"
      end
    end
    private_class_method :detect_clipboard
  end
end
