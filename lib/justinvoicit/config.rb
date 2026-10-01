# frozen_string_literal: true

require "json"
require "fileutils"

module Justinvoicit
  # Reads and writes the saved login (host, email and tokens).
  #
  # Stored at ~/.config/justinvoicit/credentials.json, readable only by the
  # current user, because the tokens give access to their account.
  class Config
    FILE_NAME = "credentials.json"

    def self.dir
      return ENV["JUSTINVOICIT_CONFIG_DIR"] if ENV["JUSTINVOICIT_CONFIG_DIR"]

      base = ENV["XDG_CONFIG_HOME"] || File.join(Dir.home, ".config")
      File.join(base, "justinvoicit")
    end

    attr_reader :path

    def initialize(path: File.join(self.class.dir, FILE_NAME))
      @path = path
      @data = load
    end

    # JUSTINVOICIT_HOST wins over the saved host, so you can point at a
    # local server (http://localhost:3000) without logging in again.
    def host
      ENV["JUSTINVOICIT_HOST"] || @data["host"] || DEFAULT_HOST
    end

    def email
      @data["email"]
    end

    def access_token
      @data["access_token"]
    end

    def refresh_token
      @data["refresh_token"]
    end

    def logged_in?
      !access_token.nil?
    end

    def update(attributes)
      @data = @data.merge(attributes.transform_keys(&:to_s))
      save
    end

    def clear
      @data = {}
      FileUtils.rm_f(path)
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
      # Create the file as 0600 so the tokens are never readable by others,
      # even for a moment; chmod covers a file that already existed.
      File.open(path, "w", 0o600) { |f| f.write(JSON.pretty_generate(@data)) }
      File.chmod(0o600, path)
    end
  end
end
