# frozen_string_literal: true

require "json"
require "net/http"
require "openssl"
require "uri"

module Justinvoicit
  # Talks to the JustInvoicIt JSON API (/api/*).
  #
  # Access tokens last 1 day and refresh tokens 7 days. When a request comes
  # back 401, the client swaps the refresh token for a new pair, saves it and
  # retries once, so users only have to log in again after a week of inactivity.
  class ApiClient
    OPEN_TIMEOUT = 10
    READ_TIMEOUT = 30

    NETWORK_ERRORS = [
      SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH,
      Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError
    ].freeze

    def initialize(config)
      @config = config
    end

    # POST /api/sessions -> { access_token, refresh_token }
    def login(email, password)
      request(:post, "/api/sessions", body: { email: email, password: password }, token: nil)
    end

    # GET /api/sessions -> { user: { id, email, full_name, business_name } }
    def current_user
      authenticated(:get, "/api/sessions")["user"]
    end

    # DELETE /api/sessions with the refresh token -> revokes it on the server
    def logout
      request(:delete, "/api/sessions", token: @config.refresh_token)
    end

    # GET /api/invoices -> [ { id, name, amount, currency, status, due_date, client, line_items } ]
    def invoices
      authenticated(:get, "/api/invoices")["invoices"]
    end

    private

    def authenticated(method, path)
      raise NotLoggedInError unless @config.logged_in?

      request(method, path, token: @config.access_token)
    rescue ApiError => e
      raise unless e.status == 401

      refresh_tokens!
      request(method, path, token: @config.access_token)
    end

    def refresh_tokens!
      raise NotLoggedInError, "Your session has expired. Run `justinvoicit login` again." unless @config.refresh_token

      tokens = request(:patch, "/api/sessions", token: @config.refresh_token)
      @config.update(access_token: tokens["access_token"], refresh_token: tokens["refresh_token"])
    rescue ApiError
      @config.clear
      raise NotLoggedInError, "Your session has expired. Run `justinvoicit login` again."
    end

    def request(method, path, body: nil, token: nil)
      uri = URI.join(@config.host, path)
      req = build_request(method, uri, body, token)

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                                     open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        http.request(req)
      end

      handle(response)
    rescue *NETWORK_ERRORS => e
      raise Error, "Could not connect to #{@config.host} (#{e.class}: #{e.message})"
    end

    def build_request(method, uri, body, token)
      klass = { get: Net::HTTP::Get, post: Net::HTTP::Post, patch: Net::HTTP::Patch, delete: Net::HTTP::Delete }.fetch(method)
      req = klass.new(uri)
      req["Accept"] = "application/json"
      req["User-Agent"] = "justinvoicit-cli/#{VERSION}"
      req["Authorization"] = "Bearer #{token}" if token
      if body
        req["Content-Type"] = "application/json"
        req.body = JSON.generate(body)
      end
      req
    end

    def handle(response)
      data = parse(response)
      return data if response.is_a?(Net::HTTPSuccess)

      message = data["error"] || "Request failed with HTTP #{response.code}"
      raise ApiError.new(message, status: response.code.to_i)
    end

    # Errors like 404/500 can come back as HTML pages, so don't assume JSON.
    def parse(response)
      body = response.body.to_s
      return {} if body.empty?

      JSON.parse(body)
    rescue JSON::ParserError
      {}
    end
  end
end
