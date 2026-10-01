# frozen_string_literal: true

require "tmpdir"
require "webmock/rspec"
require_relative "../lib/justinvoicit"

HOST = "https://justinvoicit.test"

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.order = :random

  # Every test gets its own empty config dir and a fake host, so tests never
  # touch your real ~/.config/justinvoicit or hit a real server.
  config.around do |example|
    Dir.mktmpdir do |dir|
      ENV["JUSTINVOICIT_CONFIG_DIR"] = dir
      ENV["JUSTINVOICIT_HOST"] = HOST
      example.run
    ensure
      ENV.delete("JUSTINVOICIT_CONFIG_DIR")
      ENV.delete("JUSTINVOICIT_HOST")
    end
  end
end

# Accepts json_response({ error: "x" }, status: 401) or json_response(access_token: "a").
def json_response(body = nil, status: 200, **fields)
  { status: status, body: JSON.generate(body || fields), headers: { "Content-Type" => "application/json" } }
end

def log_in(access_token: "access-1", refresh_token: "refresh-1")
  Justinvoicit::Config.new.update(email: "jane@example.com", access_token: access_token, refresh_token: refresh_token)
end
