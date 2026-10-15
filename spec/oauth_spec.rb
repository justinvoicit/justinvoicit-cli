# frozen_string_literal: true

RSpec.describe Justinvoicit::OAuth do
  subject(:oauth) { described_class.new(HOST) }

  describe "#login" do
    it "sends a PKCE authorize request with a loopback redirect URI" do
      captured = nil
      stub_request(:post, "#{HOST}/oauth/token").to_return(json_response(token_response))

      oauth.login(open_browser: lambda { |url|
        captured = url
        approve_in_browser(url)
      })

      params = URI.decode_www_form(URI(captured).query).to_h
      expect(captured).to start_with("#{HOST}/oauth/authorize?")
      expect(params).to include("client_id" => "justinvoicit-cli", "response_type" => "code",
                                "scope" => "profile invoices:read", "code_challenge_method" => "S256")
      expect(params["redirect_uri"]).to match(%r{\Ahttp://127\.0\.0\.1:\d+/callback\z})
      expect(params["state"]).not_to be_empty
    end

    it "exchanges the code with the verifier that matches the challenge" do
      challenge = nil
      redirect_uri = nil
      stub = stub_request(:post, "#{HOST}/oauth/token").with do |request|
        form = URI.decode_www_form(request.body).to_h
        form["grant_type"] == "authorization_code" && form["code"] == "the-code" &&
          form["client_id"] == "justinvoicit-cli" && form["redirect_uri"] == redirect_uri &&
          Base64.urlsafe_encode64(Digest::SHA256.digest(form["code_verifier"]), padding: false) == challenge
      end.to_return(json_response(token_response))

      tokens = oauth.login(open_browser: lambda { |url|
        params = URI.decode_www_form(URI(url).query).to_h
        challenge = params["code_challenge"]
        redirect_uri = params["redirect_uri"]
        approve_in_browser(url)
      })

      expect(stub).to have_been_requested
      expect(tokens["access_token"]).to eq("access-1")
    end

    it "shows the browser a page saying sign-in worked" do
      stub_request(:post, "#{HOST}/oauth/token").to_return(json_response(token_response))
      browser = nil

      oauth.login(open_browser: ->(url) { browser = approve_in_browser(url) })

      response = browser.value
      expect(response.code).to eq("200")
      expect(response.body).to include("You're signed in")
    end

    it "ignores other requests to the local server, such as /favicon.ico" do
      stub_request(:post, "#{HOST}/oauth/token").to_return(json_response(token_response))

      tokens = oauth.login(open_browser: lambda { |url|
        port = URI(URI.decode_www_form(URI(url).query).to_h["redirect_uri"]).port
        Thread.new do
          Net::HTTP.get_response(URI("http://127.0.0.1:#{port}/favicon.ico"))
          approve_in_browser(url).join
        end
      })

      expect(tokens["access_token"]).to eq("access-1")
    end

    it "rejects a callback whose state doesn't match" do
      expect do
        oauth.login(open_browser: ->(url) { approve_in_browser(url, state: "forged") })
      end.to raise_error(Justinvoicit::Error, /did not match/)
    end

    it "reports a sign-in the user cancelled" do
      expect do
        oauth.login(open_browser: lambda { |url|
          callback = URI(URI.decode_www_form(URI(url).query).to_h["redirect_uri"])
          callback.query = "error=access_denied&error_description=The+user+denied+the+request"
          Thread.new { Net::HTTP.get_response(callback) }
        })
      end.to raise_error(Justinvoicit::Error, "The user denied the request")
    end

    it "gives up when the browser never comes back" do
      expect { oauth.login(open_browser: ->(_url) {}, timeout: 0.2) }
        .to raise_error(Justinvoicit::Error, /Timed out/) { |e| expect(e.code).to eq("auth_required") }
    end
  end

  describe "#refresh" do
    it "treats a rejected refresh token as needing a new login" do
      stub_request(:post, "#{HOST}/oauth/token")
        .with(body: hash_including(grant_type: "refresh_token", refresh_token: "old", client_id: "justinvoicit-cli"))
        .to_return(json_response({ error: "invalid_grant", error_description: "The refresh token is invalid." },
                                 status: 400))

      expect { oauth.refresh("old") }
        .to raise_error(Justinvoicit::ApiError) { |e| expect(e.code).to eq("auth_required") }
    end
  end
end
