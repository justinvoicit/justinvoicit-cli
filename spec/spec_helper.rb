# frozen_string_literal: true

require "tmpdir"
require "webmock/rspec"
require_relative "../lib/justinvoicit"

HOST = "https://justinvoicit.test"

# The login flow runs a real server on 127.0.0.1, which the fake browser calls.
WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.order = :random

  # Every test gets its own empty config dir, a fake host and file-based
  # credentials, so tests never touch your real ~/.config/justinvoicit, your
  # Keychain, or a real server.
  config.around do |example|
    Dir.mktmpdir do |dir|
      ENV["JUSTINVOICIT_CONFIG_DIR"] = dir
      ENV["JUSTINVOICIT_HOST"] = HOST
      ENV["JUSTINVOICIT_NO_KEYRING"] = "1"
      example.run
    ensure
      %w[JUSTINVOICIT_CONFIG_DIR JUSTINVOICIT_HOST JUSTINVOICIT_NO_KEYRING].each { |name| ENV.delete(name) }
    end
  end
end

# Accepts json_response({ error: "x" }, status: 401) or json_response(access_token: "a").
def json_response(body = nil, status: 200, **fields)
  { status: status, body: JSON.generate(body || fields), headers: { "Content-Type" => "application/json" } }
end

def token_response(access_token: "access-1", refresh_token: "refresh-1", expires_in: 3600)
  { "access_token" => access_token, "refresh_token" => refresh_token, "expires_in" => expires_in,
    "scope" => "profile invoices:read", "token_type" => "Bearer" }
end

def log_in(**tokens)
  Justinvoicit::Session.new(HOST).save(token_response(**tokens))
end

def saved_credentials
  Justinvoicit::Credentials::FileStore.new.read(HOST)
end

# Plays the browser: approves the sign-in by calling the CLI's redirect URI.
def approve_in_browser(url, code: "the-code", state: nil)
  params = URI.decode_www_form(URI(url).query).to_h
  callback = URI(params["redirect_uri"])
  callback.query = URI.encode_www_form(code: code, state: state || params["state"])
  Thread.new { Net::HTTP.get_response(callback) }
end
