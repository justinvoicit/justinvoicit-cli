# frozen_string_literal: true

require "rbconfig"

module Justinvoicit
  # Opens a URL in the user's default browser. Returns false when it can't,
  # e.g. over SSH or on a machine with no desktop.
  module Browser
    def self.open(url)
      command = RbConfig::CONFIG["host_os"].match?(/darwin/) ? "open" : "xdg-open"
      system(command, url, out: File::NULL, err: File::NULL) || false
    rescue SystemCallError
      false
    end
  end
end
