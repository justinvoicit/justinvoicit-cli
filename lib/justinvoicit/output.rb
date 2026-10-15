# frozen_string_literal: true

require "json"

module Justinvoicit
  # Prints results for people or, with --json, for scripts and agents.
  #
  # JSON goes to stdout as one envelope per command:
  #   { "ok": true,  "data": ... }
  #   { "ok": false, "error": "...", "code": "auth_required", "hint": "..." }
  # Progress messages always go to stderr, so stdout stays parseable.
  class Output
    def initialize(json:, stdout: $stdout, stderr: $stderr)
      @json = json
      @stdout = stdout
      @stderr = stderr
    end

    def json?
      @json
    end

    def success(data, message)
      if json?
        @stdout.puts JSON.generate(ok: true, data: data)
      else
        @stdout.puts message
      end
    end

    def error(error)
      if json?
        @stdout.puts JSON.generate({ ok: false, error: error.message, code: error.code, hint: error.hint }.compact)
      else
        @stderr.puts "Error: #{error.message}"
        @stderr.puts "Hint: #{error.hint}" if error.hint
      end
    end

    def progress(message)
      @stderr.puts message
    end
  end
end
