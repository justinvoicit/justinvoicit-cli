# frozen_string_literal: true

RSpec.describe Justinvoicit::CLI do
  # Runs the CLI like a user would and captures what it prints.
  def run_cli(*args)
    out = StringIO.new
    err = StringIO.new
    $stdout = out
    $stderr = err
    status = 0
    begin
      described_class.start(args)
    rescue SystemExit => e
      status = e.status
    ensure
      $stdout = STDOUT
      $stderr = STDERR
    end
    { out: out.string, err: err.string, status: status }
  end

  let(:invoices) do
    [
      { "identifier" => "3", "name" => "Website", "amount" => 1500.0, "currency" => "usd", "status" => "pending",
        "due_date" => "2026-10-15", "client" => { "id" => 1, "full_name" => "Acme Inc" } },
      { "identifier" => "2", "name" => "Logo", "amount" => 200.5, "currency" => "inr", "status" => "paid",
        "due_date" => "2026-09-01", "client" => { "id" => 2, "full_name" => "Globex" } }
    ]
  end

  it "prints the version" do
    expect(run_cli("--version")[:out]).to eq("justinvoicit #{Justinvoicit::VERSION}\n")
  end

  describe "login" do
    # Simulates `echo secret | justinvoicit login ...` (stdin is not a terminal).
    around do |example|
      $stdin = StringIO.new("secret\n")
      example.run
    ensure
      $stdin = STDIN
    end

    it "saves the tokens" do
      stub_request(:post, "#{HOST}/api/sessions").to_return(json_response(access_token: "a", refresh_token: "r"))

      result = run_cli("login", "--email", "jane@example.com")

      expect(result[:out]).to include("Logged in as jane@example.com")
      expect(Justinvoicit::Config.new.access_token).to eq("a")
    end

    it "fails with exit status 1 on bad credentials" do
      stub_request(:post, "#{HOST}/api/sessions").to_return(json_response({ error: "Invalid credentials" }, status: 401))

      result = run_cli("login", "--email", "jane@example.com")

      expect(result[:status]).to eq(1)
      expect(result[:err]).to include("Invalid credentials")
      expect(Justinvoicit::Config.new).not_to be_logged_in
    end

    it "sends the piped password" do
      login = stub_request(:post, "#{HOST}/api/sessions")
              .with(body: { email: "jane@example.com", password: "secret" })
              .to_return(json_response(access_token: "a", refresh_token: "r"))

      run_cli("login", "--email", "jane@example.com")

      expect(login).to have_been_requested
    end

    it "rejects a blank password without calling the server" do
      $stdin = StringIO.new("\n")

      result = run_cli("login", "--email", "jane@example.com")

      expect(result[:status]).to eq(1)
      expect(result[:err]).to include("Password can't be blank")
    end
  end

  describe "logout" do
    it "revokes the session and removes saved credentials" do
      log_in
      revoke = stub_request(:delete, "#{HOST}/api/sessions")
               .with(headers: { "Authorization" => "Bearer refresh-1" })
               .to_return(json_response(message: "Logout successful"))

      expect(run_cli("logout")[:out]).to include("Logged out.")
      expect(revoke).to have_been_requested
      expect(Justinvoicit::Config.new).not_to be_logged_in
    end

    it "still logs out locally when the server is unreachable" do
      log_in
      stub_request(:delete, "#{HOST}/api/sessions").to_raise(SocketError)

      result = run_cli("logout")

      expect(result[:out]).to include("Warning", "Logged out.")
      expect(Justinvoicit::Config.new).not_to be_logged_in
    end
  end

  describe "whoami" do
    it "shows the current user" do
      log_in
      stub_request(:get, "#{HOST}/api/sessions")
        .to_return(json_response(user: { email: "jane@example.com", full_name: "Jane Doe" }))

      expect(run_cli("whoami")[:out]).to eq("Jane Doe <jane@example.com> on #{HOST}\n")
    end
  end

  describe "invoices list" do
    before do
      log_in
      stub_request(:get, "#{HOST}/api/invoices").to_return(json_response(invoices: invoices))
    end

    it "prints a table" do
      out = run_cli("invoices", "list")[:out]

      expect(out).to match(/#\s+NAME\s+CLIENT\s+AMOUNT\s+STATUS\s+DUE/)
      expect(out).to match(/3\s+Website\s+Acme Inc\s+1500.00 USD\s+pending\s+2026-10-15/)
      expect(out).to include("2 invoice(s)")
    end

    it "filters by status" do
      out = run_cli("invoices", "list", "--status", "paid")[:out]

      expect(out).to include("Logo")
      expect(out).not_to include("Website")
    end

    it "limits the number of rows" do
      expect(run_cli("invoices", "list", "--limit", "1")[:out]).to include("1 invoice(s)")
    end

    it "prints JSON" do
      out = run_cli("invoices", "list", "--json")[:out]

      expect(JSON.parse(out).map { |i| i["name"] }).to eq(%w[Website Logo])
    end

    it "says when there are no invoices" do
      stub_request(:get, "#{HOST}/api/invoices").to_return(json_response(invoices: []))

      expect(run_cli("invoices", "list")[:out]).to eq("No invoices found.\n")
    end
  end

  it "asks to log in when not logged in" do
    result = run_cli("invoices", "list")

    expect(result[:status]).to eq(1)
    expect(result[:err]).to include("not logged in")
  end
end
