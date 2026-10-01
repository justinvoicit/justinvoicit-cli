# frozen_string_literal: true

RSpec.describe Justinvoicit::Config do
  it "is not logged in when nothing is saved" do
    expect(described_class.new).not_to be_logged_in
  end

  it "saves and reloads credentials" do
    described_class.new.update(email: "jane@example.com", access_token: "a", refresh_token: "r")

    config = described_class.new
    expect(config).to be_logged_in
    expect(config.email).to eq("jane@example.com")
    expect(config.refresh_token).to eq("r")
  end

  it "makes the credentials file readable only by the owner" do
    config = described_class.new
    config.update(access_token: "a")

    expect(File.stat(config.path).mode & 0o777).to eq(0o600)
  end

  it "removes the file on clear" do
    config = described_class.new
    config.update(access_token: "a")
    config.clear

    expect(File.exist?(config.path)).to be(false)
    expect(described_class.new).not_to be_logged_in
  end

  it "prefers JUSTINVOICIT_HOST over the saved host" do
    described_class.new.update(host: "https://saved.example")

    expect(described_class.new.host).to eq(HOST)
  end

  it "falls back to the default host" do
    ENV.delete("JUSTINVOICIT_HOST")

    expect(described_class.new.host).to eq(Justinvoicit::DEFAULT_HOST)
  end

  it "treats a corrupt file as logged out" do
    config = described_class.new
    FileUtils.mkdir_p(File.dirname(config.path))
    File.write(config.path, "not json")

    expect(described_class.new).not_to be_logged_in
  end
end
