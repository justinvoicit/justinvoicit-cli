# frozen_string_literal: true

require "thor"

module Justinvoicit
  module Commands
    # Shared setup for every command group.
    class Base < Thor
      # Exit with status 1 on errors, so scripts can check `$?`.
      def self.exit_on_failure?
        true
      end

      no_commands do
        def config
          @config ||= Config.new
        end

        def api
          @api ||= ApiClient.new(config)
        end

        # Turn our errors into Thor::Error, which Thor prints as a clean
        # one-line message (no Ruby backtrace) and exits with status 1.
        def with_errors
          yield
        rescue Justinvoicit::Error => e
          raise Thor::Error, set_color("Error: #{e.message}", :red)
        end
      end
    end
  end
end
