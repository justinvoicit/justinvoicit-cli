# frozen_string_literal: true

module Justinvoicit
  DEFAULT_HOST = "https://justinvoicit.com"

  # The CLI is a public OAuth client (no secret): it signs in with PKCE.
  CLIENT_ID = "justinvoicit-cli"
  SCOPE = "profile invoices:read"
end

require_relative "justinvoicit/version"
require_relative "justinvoicit/errors"
require_relative "justinvoicit/config"
require_relative "justinvoicit/credentials"
require_relative "justinvoicit/http"
require_relative "justinvoicit/browser"
require_relative "justinvoicit/oauth"
require_relative "justinvoicit/session"
require_relative "justinvoicit/api_client"
require_relative "justinvoicit/output"
require_relative "justinvoicit/cli"
