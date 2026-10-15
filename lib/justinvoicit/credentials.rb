# frozen_string_literal: true

require "base64"
require "fileutils"
require "json"
require "open3"

module Justinvoicit
  # Saved OAuth tokens, one entry per host.
  #
  # On macOS they go in the login Keychain. Elsewhere, or when the Keychain
  # can't be used, they go in ~/.config/justinvoicit/credentials.json with
  # 0600 permissions. JUSTINVOICIT_NO_KEYRING=1 forces the file.
  module Credentials
    def self.store
      if KeychainStore.available?
        KeychainStore.new(fallback: FileStore.new)
      else
        FileStore.new
      end
    end

    # Stores each host's tokens as a generic password, service "justinvoicit-cli".
    class KeychainStore
      SERVICE = "justinvoicit-cli"
      SECURITY = "/usr/bin/security"
      NOT_FOUND = 44 # `security` exit status for "item not found"

      def self.available?
        RUBY_PLATFORM.include?("darwin") && File.executable?(SECURITY) && ENV["JUSTINVOICIT_NO_KEYRING"].to_s.empty?
      end

      def initialize(fallback:)
        @fallback = fallback
      end

      def read(host)
        out, status = Open3.capture2(SECURITY, "find-generic-password", "-s", SERVICE, "-a", host, "-w",
                                     err: File::NULL)
        return @fallback.read(host) unless status.success?

        JSON.parse(Base64.strict_decode64(out.strip))
      rescue ArgumentError, JSON::ParserError
        nil
      end

      # The secret is passed on stdin (`security -i`), never on the command
      # line, where other users could see it in `ps`. Base64 keeps the value
      # free of quotes and spaces, which that interactive syntax can't escape.
      def write(host, data)
        secret = Base64.strict_encode64(JSON.generate(data))
        command = %(add-generic-password -U -s "#{SERVICE}" -a "#{host}" -w "#{secret}"\n)
        _out, status = Open3.capture2e(SECURITY, "-i", stdin_data: command)
        return @fallback.delete(host) if status.success?

        warn "Warning: could not save to the macOS Keychain, saving to #{@fallback.path} instead"
        @fallback.write(host, data)
      end

      def delete(host)
        Open3.capture2e(SECURITY, "delete-generic-password", "-s", SERVICE, "-a", host)
        @fallback.delete(host)
      end
    end

    # A JSON file readable only by the current user: { "<host>": { tokens } }.
    class FileStore
      attr_reader :path

      def initialize(path: File.join(Config.dir, "credentials.json"))
        @path = path
      end

      def read(host)
        load[host]
      end

      def write(host, data)
        save(load.merge(host => data))
      end

      def delete(host)
        all = load
        return unless all.delete(host)

        all.empty? ? FileUtils.rm_f(path) : save(all)
      end

      private

      def load
        return {} unless File.exist?(path)

        JSON.parse(File.read(path))
      rescue JSON::ParserError
        {}
      end

      def save(all)
        FileUtils.mkdir_p(File.dirname(path), mode: 0o700)
        # Create the file as 0600 so the tokens are never readable by others,
        # even for a moment; chmod covers a file that already existed.
        File.open(path, "w", 0o600) { |f| f.write(JSON.pretty_generate(all)) }
        File.chmod(0o600, path)
      end
    end
  end
end
