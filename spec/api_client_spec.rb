# frozen_string_literal: true

RSpec.describe Justinvoicit::ApiClient do
  subject(:client) { described_class.new(config) }

  let(:config) { Justinvoicit::Config.new }

  describe "#login" do
    it "returns the tokens" do
      stub_request(:post, "#{HOST}/api/sessions")
        .with(body: { email: "jane@example.com", password: "secret" })
        .to_return(json_response(access_token: "a", refresh_token: "r"))

      expect(client.login("jane@example.com", "secret")).to include("access_token" => "a")
    end

    it "raises the server's error message on bad credentials" do
      stub_request(:post, "#{HOST}/api/sessions").to_return(json_response({ error: "Invalid credentials" }, status: 401))

      expect { client.login("jane@example.com", "wrong") }
        .to raise_error(Justinvoicit::ApiError, "Invalid credentials")
    end
  end

  describe "#invoices" do
    it "raises NotLoggedInError without saved credentials" do
      expect { client.invoices }.to raise_error(Justinvoicit::NotLoggedInError)
    end

    it "sends the access token" do
      log_in
      stub_request(:get, "#{HOST}/api/invoices")
        .with(headers: { "Authorization" => "Bearer access-1" })
        .to_return(json_response(invoices: [{ "id" => 1 }]))

      expect(client.invoices).to eq([{ "id" => 1 }])
    end

    context "when the access token has expired" do
      before do
        log_in
        stub_request(:get, "#{HOST}/api/invoices")
          .with(headers: { "Authorization" => "Bearer access-1" })
          .to_return(json_response({ error: "Invalid token" }, status: 401))
      end

      it "refreshes the tokens, saves them and retries" do
        stub_request(:patch, "#{HOST}/api/sessions")
          .with(headers: { "Authorization" => "Bearer refresh-1" })
          .to_return(json_response(access_token: "access-2", refresh_token: "refresh-2"))
        stub_request(:get, "#{HOST}/api/invoices")
          .with(headers: { "Authorization" => "Bearer access-2" })
          .to_return(json_response(invoices: []))

        expect(client.invoices).to eq([])
        expect(Justinvoicit::Config.new.refresh_token).to eq("refresh-2")
      end

      it "clears the login and asks to log in again when the refresh fails" do
        stub_request(:patch, "#{HOST}/api/sessions").to_return(json_response({ error: "Invalid refresh token" }, status: 401))

        expect { client.invoices }.to raise_error(Justinvoicit::NotLoggedInError, /session has expired/)
        expect(Justinvoicit::Config.new).not_to be_logged_in
      end
    end

    it "handles non-JSON error pages" do
      log_in
      stub_request(:get, "#{HOST}/api/invoices").to_return(status: 500, body: "<html>oops</html>")

      expect { client.invoices }.to raise_error(Justinvoicit::ApiError, "Request failed with HTTP 500")
    end

    it "explains connection failures" do
      log_in
      stub_request(:get, "#{HOST}/api/invoices").to_raise(Errno::ECONNREFUSED)

      expect { client.invoices }.to raise_error(Justinvoicit::Error, /Could not connect to #{HOST}/)
    end
  end
end
