# frozen_string_literal: true

RSpec.describe Justinvoicit::CLI do
  let(:user) { { "id" => 7, "email" => "ada@example.com", "full_name" => "Ada Lovelace", "business_name" => "Engines" } }

  # Runs the CLI and returns [stdout, stderr, exit status].
  def run_cli(*args)
    stdout = StringIO.new
    stderr = StringIO.new
    status = 0
    begin
      $stdout = stdout
      $stderr = stderr
      described_class.start(args)
    rescue SystemExit => e
      status = e.status
    ensure
      $stdout = STDOUT
      $stderr = STDERR
    end
    [stdout.string, stderr.string, status]
  end

  def stub_me(token: "access-1")
    stub_request(:get, "#{HOST}/api/v1/me")
      .with(headers: { "Authorization" => "Bearer #{token}", "User-Agent" => "justinvoicit-cli/#{Justinvoicit::VERSION}" })
      .to_return(json_response(user: user))
  end

  describe "login" do
    before do
      allow(Justinvoicit::Browser).to receive(:open) { |url| approve_in_browser(url) }
      stub_request(:post, "#{HOST}/oauth/token").to_return(json_response(token_response))
      stub_me
    end

    it "signs in through the browser and saves the tokens" do
      stdout, stderr, status = run_cli("login")

      expect(status).to eq(0)
      expect(stderr).to include("#{HOST}/oauth/authorize?")
      expect(stdout).to eq("Logged in as Ada Lovelace <ada@example.com> (Engines) on #{HOST}\n")
      expect(saved_credentials).to include("access_token" => "access-1", "refresh_token" => "refresh-1")
    end

    it "only prints the URL with --no-browser" do
      stub_const("Justinvoicit::OAuth::LOGIN_TIMEOUT", 0.1)

      _stdout, stderr, status = run_cli("login", "--no-browser")

      expect(stderr).to include("#{HOST}/oauth/authorize?", "Timed out waiting for the browser sign-in")
      expect(status).to eq(3)
      expect(saved_credentials).to be_nil
      expect(Justinvoicit::Browser).not_to have_received(:open)
    end

    it "prints JSON with --json" do
      stdout, _stderr, _status = run_cli("login", "--json")

      expect(JSON.parse(stdout)).to eq("ok" => true, "data" => { "host" => HOST, "user" => user })
    end
  end

  describe "whoami" do
    it "shows the signed-in user" do
      log_in
      stub_me

      stdout, _stderr, status = run_cli("whoami")

      expect(status).to eq(0)
      expect(stdout).to eq("Ada Lovelace <ada@example.com> (Engines) on #{HOST}\n")
    end

    it "refreshes and retries once when the token is rejected" do
      log_in
      stub_request(:get, "#{HOST}/api/v1/me").with(headers: { "Authorization" => "Bearer access-1" })
                                          .to_return(json_response({ error: "unauthorized" }, status: 401))
      stub_request(:post, "#{HOST}/oauth/token")
        .to_return(json_response(token_response(access_token: "access-2", refresh_token: "refresh-2")))
      stub_me(token: "access-2")

      stdout, _stderr, status = run_cli("me")

      expect(status).to eq(0)
      expect(stdout).to include("Ada Lovelace")
    end

    it "exits 3 with a hint when not logged in" do
      stdout, stderr, status = run_cli("whoami")

      expect(status).to eq(3)
      expect(stdout).to be_empty
      expect(stderr).to eq("Error: You are not logged in.\nHint: Run `justinvoicit login`\n")
    end

    it "reports errors as JSON with --json" do
      stdout, _stderr, status = run_cli("whoami", "--json")

      expect(status).to eq(3)
      expect(JSON.parse(stdout)).to eq("ok" => false, "error" => "You are not logged in.",
                                       "code" => "auth_required", "hint" => "Run `justinvoicit login`")
    end

    it "exits 6 when the server can't be reached" do
      log_in
      stub_request(:get, "#{HOST}/api/v1/me").to_raise(SocketError)

      _stdout, stderr, status = run_cli("whoami")

      expect(status).to eq(6)
      expect(stderr).to include("Could not connect to justinvoicit.test")
    end
  end

  describe "logout" do
    it "revokes the session and removes the tokens" do
      log_in
      stub_request(:post, "#{HOST}/oauth/revoke").to_return(json_response({}))

      stdout, _stderr, status = run_cli("logout")

      expect(status).to eq(0)
      expect(stdout).to eq("Logged out of #{HOST}\n")
      expect(saved_credentials).to be_nil
    end

    it "still removes the tokens when the server can't be reached" do
      log_in
      stub_request(:post, "#{HOST}/oauth/revoke").to_raise(SocketError)

      _stdout, stderr, status = run_cli("logout")

      expect(status).to eq(0)
      expect(stderr).to include("Warning: could not revoke the session on the server")
      expect(saved_credentials).to be_nil
    end
  end

  it "rejects a plain-http host that isn't local" do
    _stdout, stderr, status = run_cli("login", "--host", "http://example.com")

    expect(status).to eq(1)
    expect(stderr).to include('Invalid host "http://example.com"')
  end
end
