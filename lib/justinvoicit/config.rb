# frozen_string_literal: true

require "json"
require "fileutils"
require "uri"

module Justinvoicit
  # Non-secret settings, saved at ~/.config/justinvoicit/config.json.
  # Tokens are kept separately by Credentials.
  class Config
    LOOPBACK_HOSTS = %w[localhost 127.0.0.1 ::1 [::1]].freeze

    def self.dir
      return ENV["JUSTINVOICIT_CONFIG_DIR"] if ENV["JUSTINVOICIT_CONFIG_DIR"]

      base = ENV["XDG_CONFIG_HOME"] || File.join(Dir.home, ".config")
      File.join(base, "justinvoicit")
    end

    # Tokens are sent to the host, so only allow plain http for a local server.
    def self.validate_host!(host)
      uri = URI.parse(host)
      return host.chomp("/") if uri.scheme == "https" && uri.host
      return host.chomp("/") if uri.scheme == "http" && LOOPBACK_HOSTS.include?(uri.host)

      raise Error.new("Invalid host #{host.inspect}", code: "usage",
                                                      hint: "Use an https:// URL, or http://localhost for a local server")
    rescue URI::InvalidURIError
      raise Error.new("Invalid host #{host.inspect}", code: "usage")
    end

    attr_reader :path

    def initialize(path: File.join(self.class.dir, "config.json"))
      @path = path
      @data = load
    end

    # JUSTINVOICIT_HOST wins over the saved host, so you can point one command
    # at a local server (http://localhost:3000) without changing the saved one.
    def host
      self.class.validate_host!(ENV["JUSTINVOICIT_HOST"] || @data["host"] || DEFAULT_HOST)
    end

    def host=(value)
      @data["host"] = self.class.validate_host!(value)
      save
    end

    private

    def load
      return {} unless File.exist?(path)

      JSON.parse(File.read(path))
    rescue JSON::ParserError
      {}
    end

    def save
      FileUtils.mkdir_p(File.dirname(path), mode: 0o700)
      File.write(path, JSON.pretty_generate(@data))
    end
  end
end
