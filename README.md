# JustInvoicIt CLI

Manage your [JustInvoicIt](https://justinvoicit.com) invoices from the terminal.

## Installation

Requires Ruby 3.0 or newer.

```sh
curl -fsSL https://raw.githubusercontent.com/justinvoicit/justinvoicit-cli/main/install.sh | sh
```

Then open a new terminal (or `source` the file the installer mentions) and run:

```sh
justinvoicit login
```

Install a specific version:

```sh
curl -fsSL https://raw.githubusercontent.com/justinvoicit/justinvoicit-cli/main/install.sh | JUSTINVOICIT_VERSION=v0.1.0 sh
```

To upgrade, run the install command again.
```sh
curl -fsSL https://raw.githubusercontent.com/justinvoicit/justinvoicit-cli/main/install.sh | sh
```

## Usage

```sh
justinvoicit login     # sign in through your browser
justinvoicit whoami    # show who you're signed in as (alias: me)
justinvoicit logout    # sign out and remove the saved tokens
justinvoicit version
```

`login` opens your browser on JustInvoicIt. Sign in, click **Authorize**, and the browser hands the
sign-in back to the CLI on a local `127.0.0.1` port. If the browser doesn't open (over SSH, say), copy
the URL the CLI prints, or use `--no-browser` to only print it.

Tokens refresh automatically, so you stay signed in until you run `logout`.

### Scripts and agents

Add `--json` to any command to get a single JSON object on stdout:

```sh
$ justinvoicit whoami --json
{"ok":true,"data":{"host":"https://justinvoicit.com","user":{"id":7,"email":"ada@example.com",...}}}

$ justinvoicit whoami --json
{"ok":false,"error":"You are not logged in.","code":"auth_required","hint":"Run `justinvoicit login`"}
```

Exit codes:

| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | Usage error, such as an invalid `--host` |
| 2 | Not found |
| 3 | Not logged in, or the session expired: run `justinvoicit login` |
| 4 | Forbidden |
| 6 | Network error: the server couldn't be reached |
| 7 | Any other API error |

### Where things are stored

| What | Where |
|---|---|
| Tokens | macOS Keychain (service `justinvoicit-cli`). On other systems, or if the Keychain can't be used: `~/.config/justinvoicit/credentials.json`, readable only by you |
| Settings | `~/.config/justinvoicit/config.json` (the server set with `login --host`) |

### Environment variables

| Variable | Effect |
|---|---|
| `JUSTINVOICIT_HOST` | Server to use for this command, e.g. `http://localhost:3000` |
| `JUSTINVOICIT_CONFIG_DIR` | Use this directory instead of `~/.config/justinvoicit` |
| `JUSTINVOICIT_NO_KEYRING=1` | Store tokens in the file even on macOS |

## Development

```sh
bundle install
bundle exec rspec
```

To sign in against a local server, run the JustInvoicIt app on port 3000 (`bin/rails db:migrate` creates
the CLI's OAuth app), then:

```sh
bin/justinvoicit login --host http://localhost:3000
```

### Releasing

1. Bump `Justinvoicit::VERSION` in `lib/justinvoicit/version.rb`.
2. Commit, then tag and push: `git tag v0.1.0 && git push origin v0.1.0`.
3. Create a GitHub Release for the tag. The installer picks up the latest release.
