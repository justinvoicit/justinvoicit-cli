# frozen_string_literal: true

require "thor"

module Justinvoicit
  # Entry point: `justinvoicit <command>`.
  class CLI < Thor
    class_option :json, type: :boolean, default: false, desc: "Print JSON instead of text"

    map %w[--version -v] => :version
    map "me" => :whoami

    def self.exit_on_failure?
      true
    end

    desc "login", "Sign in to JustInvoicIt in your browser"
    method_option :host, type: :string, desc: "Server URL, saved for later commands (default: #{DEFAULT_HOST})"
    method_option :browser, type: :boolean, default: true, desc: "Open the browser (--no-browser prints the URL instead)"
    def login
      run_command do
        config.host = options[:host] if options[:host]
        tokens = OAuth.new(config.host).login(open_browser: method(:open_browser))
        session.save(tokens)

        user = api.me
        output.success({ host: config.host, user: user }, "Logged in as #{display_name(user)} on #{config.host}")
      end
    end

    desc "logout", "Sign out and remove the saved tokens"
    def logout
      run_command do
        unless session.logged_in?
          output.success({ host: config.host, logged_out: false }, "You are not logged in.")
          next
        end

        begin
          session.logout
        rescue Error => e
          # The local tokens are gone either way; the server copy expires on its own.
          output.progress "Warning: could not revoke the session on the server (#{e.message})"
        end
        output.success({ host: config.host, logged_out: true }, "Logged out of #{config.host}")
      end
    end

    desc "whoami", "Show the account you are signed in as (alias: me)"
    def whoami
      run_command do
        user = api.me
        output.success({ host: config.host, user: user }, "#{display_name(user)} on #{config.host}")
      end
    end

    desc "version", "Print the CLI version"
    def version
      output.success({ version: VERSION }, "justinvoicit #{VERSION}")
    end

    no_commands do
      def config
        @config ||= Config.new
      end

      def session
        @session ||= Session.new(config.host)
      end

      def api
        @api ||= ApiClient.new(session)
      end

      def output
        @output ||= Output.new(json: options[:json])
      end

      # Prints our errors without a backtrace and exits with the error's
      # status code, so scripts can tell "log in again" (3) from "offline" (6).
      def run_command
        yield
      rescue Error => e
        output.error(e)
        exit e.exit_code
      rescue Interrupt
        output.progress ""
        exit 130
      end

      def display_name(user)
        name = user["full_name"].to_s.empty? ? user["email"] : "#{user['full_name']} <#{user['email']}>"
        user["business_name"].to_s.empty? ? name : "#{name} (#{user['business_name']})"
      end

      # Always print the URL: the browser may not open (SSH, no display), or
      # may open on a profile that isn't signed in.
      def open_browser(url)
        output.progress "Opening your browser to sign in. If it doesn't open, visit:\n\n  #{url}\n"
        Browser.open(url) if options[:browser]
      end
    end
  end
end
