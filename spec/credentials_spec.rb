# frozen_string_literal: true

RSpec.describe Justinvoicit::Credentials do
  let(:tokens) { { "access_token" => "a", "refresh_token" => "r" } }

  describe Justinvoicit::Credentials::FileStore do
    subject(:store) { described_class.new }

    it "keeps each host separate" do
      store.write(HOST, tokens)
      store.write("http://localhost:3000", tokens.merge("access_token" => "local"))

      expect(store.read(HOST)).to eq(tokens)
      expect(store.read("http://localhost:3000")["access_token"]).to eq("local")
    end

    it "is readable only by the current user" do
      store.write(HOST, tokens)

      expect(File.stat(store.path).mode & 0o777).to eq(0o600)
    end

    it "removes the file when the last host is deleted" do
      store.write(HOST, tokens)
      store.delete(HOST)

      expect(File).not_to exist(store.path)
    end
  end

  describe Justinvoicit::Credentials::KeychainStore do
    subject(:store) { described_class.new(fallback: fallback) }

    let(:fallback) { Justinvoicit::Credentials::FileStore.new }
    let(:success) { instance_double(Process::Status, success?: true) }
    let(:failure) { instance_double(Process::Status, success?: false) }

    it "passes the secret on stdin, not on the command line" do
      allow(Open3).to receive(:capture2e).and_return(["", success])

      store.write(HOST, tokens)

      expect(Open3).to have_received(:capture2e) do |*args, stdin_data:|
        expect(args).to eq(["/usr/bin/security", "-i"])
        secret = stdin_data[/-w "([^"]+)"/, 1]
        expect(JSON.parse(Base64.strict_decode64(secret))).to eq(tokens)
      end
    end

    it "reads back what it saved" do
      secret = Base64.strict_encode64(JSON.generate(tokens))
      allow(Open3).to receive(:capture2)
        .with("/usr/bin/security", "find-generic-password", "-s", "justinvoicit-cli", "-a", HOST, "-w", err: File::NULL)
        .and_return(["#{secret}\n", success])

      expect(store.read(HOST)).to eq(tokens)
    end

    it "falls back to the file when the Keychain refuses the item" do
      allow(Open3).to receive(:capture2e).and_return(["", failure])

      expect { store.write(HOST, tokens) }.to output(/could not save to the macOS Keychain/).to_stderr
      expect(fallback.read(HOST)).to eq(tokens)
    end
  end
end
