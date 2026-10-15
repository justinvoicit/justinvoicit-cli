# frozen_string_literal: true

module Justinvoicit
  # Calls the JustInvoicIt JSON API (/api/v1/*) with the session's access token.
  class ApiClient
    def initialize(session)
      @session = session
    end

    # GET /api/v1/me -> { id, email, full_name, business_name }
    def me
      get("/api/v1/me")["user"]
    end

    private

    # A 401 can still happen with an unexpired token (e.g. it was revoked),
    # so refresh once and retry before giving up.
    def get(path)
      token = @session.access_token
      status, body = HTTP.request(:get, "#{@session.host}#{path}", token: token)
      if status == 401
        token = @session.refresh!(token)["access_token"]
        status, body = HTTP.request(:get, "#{@session.host}#{path}", token: token)
      end
      return body if status.between?(200, 299)

      raise ApiError.new(body["message"] || "Request failed with HTTP #{status}", status: status)
    end
  end
end
