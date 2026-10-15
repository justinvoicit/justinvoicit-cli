# frozen_string_literal: true

require "fileutils"

module Justinvoicit
  # The signed-in session for one host: saves tokens after login and hands out
  # a valid access token, refreshing it shortly before it expires.
  class Session
    # Refresh this long before expiry, so a token never runs out mid-request.
    REFRESH_WINDOW = 5 * 60

    attr_reader :host

    def initialize(host, store: Credentials.store, oauth: OAuth.new(host))
      @host = host
      @store = store
      @oauth = oauth
    end

    def logged_in?
      !credentials.nil?
    end

    def save(token_response)
      @store.write(host, credentials_from(token_response))
    end

    def access_token
      creds = credentials || raise(NotLoggedInError)
      creds = refresh!(creds["access_token"]) if expiring?(creds)
      creds["access_token"]
    end

    # Swaps the refresh token for a new pair. `stale_token` is the access
    # token the caller has; if the saved one differs, another command already
    # refreshed and that one is returned instead.
    def refresh!(stale_token)
      # The server revokes a refresh token as soon as it's used. Without the
      # lock, two commands refreshing at once would each use the same token,
      # and the second would be logged out.
      with_lock do
        creds = credentials || raise(NotLoggedInError)
        next creds if creds["access_token"] != stale_token

        begin
          refreshed = credentials_from(@oauth.refresh(creds["refresh_token"]))
        rescue ApiError => e
          raise unless e.code == "auth_required"

          @store.delete(host)
          raise NotLoggedInError, "Your session has expired."
        end
        @store.write(host, refreshed)
        refreshed
      end
    end

    # Revokes the tokens on the server, then forgets them here. The local
    # copy is removed even if the server can't be reached.
    def logout
      creds = credentials
      return false unless creds

      begin
        @oauth.revoke(creds["refresh_token"] || creds["access_token"])
      ensure
        @store.delete(host)
      end
      true
    end

    private

    def credentials
      @store.read(host)
    end

    def credentials_from(response)
      {
        "access_token" => response.fetch("access_token"),
        "refresh_token" => response["refresh_token"],
        "expires_at" => response["expires_in"] && (Time.now.to_i + response["expires_in"].to_i),
        "scope" => response["scope"]
      }
    end

    def expiring?(creds)
      creds["expires_at"] && creds["expires_at"].to_i - REFRESH_WINDOW <= Time.now.to_i
    end

    def with_lock
      FileUtils.mkdir_p(Config.dir, mode: 0o700)
      File.open(File.join(Config.dir, "refresh.lock"), File::RDWR | File::CREAT, 0o600) do |lock|
        lock.flock(File::LOCK_EX)
        yield
      end
    end
  end
end
