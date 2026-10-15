# frozen_string_literal: true

module Justinvoicit
  # Base class for errors that are shown to the user instead of a backtrace.
  #
  # `code` is stable and machine-readable (it appears in `--json` output) and
  # decides the exit status, so scripts can tell "log in again" from "try later".
  class Error < StandardError
    EXIT_CODES = {
      "usage" => 1,
      "not_found" => 2,
      "auth_required" => 3,
      "forbidden" => 4,
      "network" => 6,
      "api_error" => 7
    }.freeze

    attr_reader :code, :hint

    def initialize(message, code: "api_error", hint: nil)
      @code = code
      @hint = hint
      super(message)
    end

    def exit_code
      EXIT_CODES.fetch(code, 1)
    end
  end

  # No saved login, or the session can't be refreshed any more.
  class NotLoggedInError < Error
    def initialize(message = "You are not logged in.")
      super(message, code: "auth_required", hint: "Run `justinvoicit login`")
    end
  end

  # A non-success HTTP response from the server.
  class ApiError < Error
    attr_reader :status

    def initialize(message, status:, code: nil)
      @status = status
      code ||= code_for(status)
      super(message, code: code, hint: code == "auth_required" ? "Run `justinvoicit login`" : nil)
    end

    private

    def code_for(status)
      case status
      when 401 then "auth_required"
      when 403 then "forbidden"
      when 404 then "not_found"
      else "api_error"
      end
    end
  end
end
