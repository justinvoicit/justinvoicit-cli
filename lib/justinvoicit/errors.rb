# frozen_string_literal: true

module Justinvoicit
  # Base class for errors that should be shown to the user as a plain message.
  class Error < StandardError; end

  # Raised when there are no saved credentials, or the session can't be refreshed.
  class NotLoggedInError < Error
    def initialize(message = "You are not logged in. Run `justinvoicit login` first.")
      super
    end
  end

  # Raised for any non-success HTTP response from the API.
  class ApiError < Error
    attr_reader :status

    def initialize(message, status: nil)
      @status = status
      super(message)
    end
  end
end
