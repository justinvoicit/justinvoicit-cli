# frozen_string_literal: true

require_relative "commands/base"
require_relative "commands/invoices"

module Justinvoicit
  # Entry point: `justinvoicit <command>`.
  class CLI < Commands::Base
    map %w[--version -v] => :version

    desc "login", "Log in to your JustInvoicIt account"
    method_option :email, type: :string, aliases: "-e", desc: "Account email (asked if not given)"
    method_option :host, type: :string, desc: "Server URL (default: #{DEFAULT_HOST})"
    def login
      with_errors do
        config.update(host: options[:host]) if options[:host]

        email = options[:email] || ask("Email:")
        password = read_password
        raise Justinvoicit::Error, "Password can't be blank" if password.empty?

        tokens = api.login(email.strip, password)
        config.update(email: email.strip, access_token: tokens["access_token"], refresh_token: tokens["refresh_token"])

        say "Logged in as #{email.strip}", :green
      end
    end

    desc "logout", "Log out and remove saved credentials"
    def logout
      with_errors do
        unless config.logged_in?
          say "You are not logged in."
          return
        end

        begin
          api.logout
        rescue Justinvoicit::Error => e
          # Still remove the local login, even if the server is unreachable.
          say "Warning: could not revoke the session on the server (#{e.message})", :yellow
        end
        config.clear
        say "Logged out.", :green
      end
    end

    desc "whoami", "Show the account you are logged in as"
    def whoami
      with_errors do
        user = api.current_user
        name = user["full_name"].to_s.empty? ? user["email"] : "#{user['full_name']} <#{user['email']}>"
        say "#{name} on #{config.host}"
      end
    end

    desc "invoices SUBCOMMAND", "Work with invoices"
    subcommand "invoices", Commands::Invoices

    desc "version", "Print the CLI version"
    def version
      say "justinvoicit #{VERSION}"
    end

    no_commands do
      # On a terminal, hide what the user types. When the password is piped in
      # (`echo "$PASS" | justinvoicit login -e me@x.com`, e.g. in CI) there is no
      # terminal to hide input on, so just read the first line of stdin.
      def read_password
        unless $stdin.tty?
          return $stdin.gets.to_s.chomp
        end

        password = ask("Password:", echo: false)
        say "" # `echo: false` leaves the cursor on the password line
        password.to_s
      end
    end
  end
end
