# JustInvoicIt CLI

Manage your [JustInvoicIt](https://justinvoicit.com) invoices from the terminal.

## Installation

Requires Ruby 3.0 or newer.

```sh
curl -fsSL https://raw.githubusercontent.com/justinvoicit/justinvoicit-cli/main/install.sh | sh
```

Then open a new terminal (or `source` the file the installer mentions) and run:

```sh
justinvoicit --help
```

Install a specific version:

```sh
curl -fsSL https://raw.githubusercontent.com/justinvoicit/justinvoicit-cli/main/install.sh | JUSTINVOICIT_VERSION=v0.1.0 sh
```

To upgrade, run the install command again.

### Uninstall

```sh
rm -rf ~/.justinvoicit ~/.config/justinvoicit
```

Then remove the `# justinvoicit` line the installer added to your shell config (`~/.zshrc`, `~/.bashrc`, ...).

## Usage

```sh
justinvoicit login                          # asks for email and password
justinvoicit whoami                         # shows the account you're logged in as
justinvoicit invoices list                  # table of your invoices
justinvoicit invoices list --status pending # only pending (draft, pending, paid)
justinvoicit invoices list --limit 5        # at most 5 rows
justinvoicit invoices list --json           # raw JSON, for scripts
justinvoicit logout                         # signs out and removes saved credentials
justinvoicit --version
```

In scripts or CI, pipe the password in:

```sh
echo "$JUSTINVOICIT_PASSWORD" | justinvoicit login --email you@example.com
```

Your login is saved in `~/.config/justinvoicit/credentials.json` (readable only by you).
You stay logged in for 7 days after your last use.

## Development

```sh
bundle install
bundle exec rspec                 # run the tests
bundle exec bin/justinvoicit      # run the CLI from source
```

Point the CLI at a local Rails server:

```sh
JUSTINVOICIT_HOST=http://localhost:3000 bundle exec bin/justinvoicit login
```

| Environment variable      | Purpose                                                     |
| ------------------------- | ----------------------------------------------------------- |
| `JUSTINVOICIT_HOST`       | Server URL (default `https://justinvoicit.com`)             |
| `JUSTINVOICIT_CONFIG_DIR` | Where credentials are stored (default `~/.config/justinvoicit`) |

### Project layout

```
bin/justinvoicit                  # entry point
lib/justinvoicit/cli.rb           # top-level commands: login, logout, whoami, version
lib/justinvoicit/commands/        # command groups (invoices ...)
lib/justinvoicit/api_client.rb    # HTTP calls to /api/*, auto token refresh
lib/justinvoicit/config.rb        # saved credentials
install.sh                        # the curl | sh installer
```

### Releasing

1. Bump `Justinvoicit::VERSION` in `lib/justinvoicit/version.rb`.
2. Commit, then tag and push: `git tag v0.1.0 && git push origin v0.1.0`.
3. Create a GitHub Release for the tag. The installer picks up the latest release.
