# frozen_string_literal: true

require "json"
require "net/http"
require "openssl"
require "uri"

module Justinvoicit
  # A small JSON-over-HTTP helper shared by OAuth and ApiClient.
  module HTTP
    OPEN_TIMEOUT = 10
    READ_TIMEOUT = 30

    NETWORK_ERRORS = [
      SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH,
      Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError
    ].freeze

    # Returns [status, parsed JSON body]. Raises only for network failures;
    # callers decide what each status means.
    def self.request(method, url, form: nil, token: nil)
      uri = URI(url)
      req = build(method, uri, form, token)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                                     open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        http.request(req)
      end
      [response.code.to_i, parse(response.body)]
    rescue *NETWORK_ERRORS => e
      raise Error.new("Could not connect to #{uri.host} (#{e.class}: #{e.message})", code: "network",
                                                                                     hint: "Check your connection and try again")
    end

    def self.build(method, uri, form, token)
      req = { get: Net::HTTP::Get, post: Net::HTTP::Post }.fetch(method).new(uri)
      req["Accept"] = "application/json"
      req["User-Agent"] = "justinvoicit-cli/#{VERSION}"
      req["Authorization"] = "Bearer #{token}" if token
      req.set_form_data(form) if form
      req
    end

    # Errors like 404/500 can come back as HTML pages, so don't assume JSON.
    def self.parse(body)
      body.to_s.empty? ? {} : JSON.parse(body)
    rescue JSON::ParserError
      {}
    end
  end
end
