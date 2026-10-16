# frozen_string_literal: true

require "base64"
require "digest"
require "securerandom"
require "socket"
require "uri"

module Justinvoicit
  # Browser sign-in against the server's Doorkeeper endpoints: authorization
  # code with PKCE, with the code delivered to a one-off server on 127.0.0.1
  # (RFC 8252). The server ignores the port on loopback redirect URIs, so the
  # CLI can take whichever port is free.
  class OAuth
    CALLBACK_PATH = "/callback"
    LOGIN_TIMEOUT = 300 # seconds to finish signing in in the browser

    def initialize(host)
      @host = host
    end

    # Runs the whole sign-in and returns the token response. Calls
    # `open_browser.(url)` with the authorize URL, then waits for the browser
    # to come back.
    def login(open_browser:, timeout: self.class::LOGIN_TIMEOUT)
      verifier = SecureRandom.urlsafe_base64(32)
      state = SecureRandom.urlsafe_base64(16)
      server = TCPServer.new("127.0.0.1", 0)
      redirect_uri = "http://127.0.0.1:#{server.addr[1]}#{CALLBACK_PATH}"

      open_browser.call(authorize_url(redirect_uri, state, challenge_for(verifier)))
      code = wait_for_code(server, state, timeout)
      token_request(grant_type: "authorization_code", code: code, redirect_uri: redirect_uri, code_verifier: verifier)
    ensure
      server&.close
    end

    def refresh(refresh_token)
      token_request(grant_type: "refresh_token", refresh_token: refresh_token)
    end

    # Revoking the refresh token also revokes its access token.
    def revoke(token)
      status, body = HTTP.request(:post, "#{@host}/oauth/revoke", form: { client_id: CLIENT_ID, token: token })
      raise ApiError.new(body["error_description"] || "Could not revoke the token", status: status) unless status == 200
    end

    def authorize_url(redirect_uri, state, code_challenge)
      query = URI.encode_www_form(
        client_id: CLIENT_ID, redirect_uri: redirect_uri, response_type: "code", scope: SCOPE,
        state: state, code_challenge: code_challenge, code_challenge_method: "S256"
      )
      "#{@host}/oauth/authorize?#{query}"
    end

    private

    def challenge_for(verifier)
      Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
    end

    def token_request(params)
      status, body = HTTP.request(:post, "#{@host}/oauth/token", form: params.merge(client_id: CLIENT_ID))
      return body if status == 200

      message = body["error_description"] || body["error"] || "Token request failed with HTTP #{status}"
      raise ApiError.new(message, status: status, code: body["error"] == "invalid_grant" ? "auth_required" : nil)
    end

    # Serves requests until the browser comes back to /callback. Anything
    # else (e.g. /favicon.ico) gets a 404 and we keep waiting.
    def wait_for_code(server, state, timeout)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
      loop do
        remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
        unless remaining.positive? && server.wait_readable(remaining)
          raise Error.new("Timed out waiting for the browser sign-in", code: "auth_required",
                                                                       hint: "Run `justinvoicit login` again")
        end

        client = server.accept
        begin
          params = read_callback(client)
          next respond(client, 404, "Not found") unless params

          return handle_callback(client, params, state)
        ensure
          client.close
        end
      end
    end

    def read_callback(client)
      request_line = client.gets.to_s
      # Drain the headers so the browser doesn't see a reset connection.
      while (line = client.gets) && line != "\r\n"; end
      target = request_line.split[1].to_s
      uri = URI.parse(target)
      return nil unless uri.path == CALLBACK_PATH

      URI.decode_www_form(uri.query.to_s).to_h
    rescue URI::InvalidURIError
      nil
    end

    def handle_callback(client, params, state)
      if params["error"]
        respond(client, 400, "Sign-in was cancelled. You can close this tab.")
        raise Error.new(params["error_description"] || "Sign-in was cancelled (#{params['error']})",
                        code: "auth_required")
      end

      # The state must match, or this callback belongs to a request we never made.
      unless params["state"] == state && params["code"]
        respond(client, 400, "Sign-in failed. Please run justinvoicit login again.")
        raise Error.new("Sign-in failed: the response from the browser did not match this login", code: "auth_required",
                                                                                                    hint: "Run `justinvoicit login` again")
      end

      respond(client, 200, "You're signed in to JustInvoicIt. You can close this tab and go back to the terminal.")
      params["code"]
    end

    def respond(client, status, message)
      body = "<!doctype html><html><head><meta charset=\"utf-8\"><title>JustInvoicIt CLI</title></head>" \
             "<body style=\"font-family: system-ui, sans-serif; margin: 4rem auto; max-width: 32rem\">" \
             "<p>#{message}</p></body></html>"
      reason = { 200 => "OK", 400 => "Bad Request", 404 => "Not Found" }.fetch(status)
      client.write("HTTP/1.1 #{status} #{reason}\r\nContent-Type: text/html; charset=utf-8\r\n" \
                   "Content-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}")
    end
  end
end
