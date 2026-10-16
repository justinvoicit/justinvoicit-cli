# frozen_string_literal: true

RSpec.describe Justinvoicit::Session do
  subject(:session) { described_class.new(HOST) }

  def stub_refresh(from: "refresh-1", to: "2")
    stub_request(:post, "#{HOST}/oauth/token")
      .with(body: hash_including(grant_type: "refresh_token", refresh_token: from))
      .to_return(json_response(token_response(access_token: "access-#{to}", refresh_token: "refresh-#{to}")))
  end

  it "returns the saved token while it is fresh" do
    log_in

    expect(session.access_token).to eq("access-1")
  end

  it "refreshes a token that expires within five minutes" do
    log_in(expires_in: 4 * 60)
    stub_refresh

    expect(session.access_token).to eq("access-2")
    expect(saved_credentials).to include("access_token" => "access-2", "refresh_token" => "refresh-2")
  end

  it "skips the refresh when another command already refreshed" do
    log_in
    refresh = stub_refresh

    log_in(access_token: "access-new", refresh_token: "refresh-new")
    expect(session.refresh!("access-1")["access_token"]).to eq("access-new")
    expect(refresh).not_to have_been_requested
  end

  it "forgets the tokens when the refresh token is rejected" do
    log_in(expires_in: 0)
    stub_request(:post, "#{HOST}/oauth/token").to_return(json_response({ error: "invalid_grant" }, status: 400))

    expect { session.access_token }.to raise_error(Justinvoicit::NotLoggedInError, "Your session has expired.")
    expect(saved_credentials).to be_nil
  end

  it "raises when nobody is logged in" do
    expect { session.access_token }.to raise_error(Justinvoicit::NotLoggedInError)
  end

  describe "#logout" do
    it "revokes the refresh token and forgets the tokens" do
      log_in
      revoke = stub_request(:post, "#{HOST}/oauth/revoke")
               .with(body: hash_including(token: "refresh-1", client_id: "justinvoicit-cli"))
               .to_return(json_response({}))

      expect(session.logout).to be(true)
      expect(revoke).to have_been_requested
      expect(saved_credentials).to be_nil
    end

    it "forgets the tokens even when the server can't be reached" do
      log_in
      stub_request(:post, "#{HOST}/oauth/revoke").to_raise(SocketError)

      expect { session.logout }.to raise_error(Justinvoicit::Error) { |e| expect(e.code).to eq("network") }
      expect(saved_credentials).to be_nil
    end
  end
end
