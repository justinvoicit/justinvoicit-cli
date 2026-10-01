# frozen_string_literal: true

module Justinvoicit
  DEFAULT_HOST = "https://justinvoicit.com"
end

require_relative "justinvoicit/version"
require_relative "justinvoicit/errors"
require_relative "justinvoicit/config"
require_relative "justinvoicit/api_client"
require_relative "justinvoicit/cli"
