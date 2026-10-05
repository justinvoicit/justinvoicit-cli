# JustInvoicIt CLI

Manage your [JustInvoicIt](https://justinvoicit.com) invoices from the terminal.

## Installation

Requires Ruby 3.0 or newer.

```sh
curl -fsSL https://raw.githubusercontent.com/justinvoicit/justinvoicit-cli/main/install.sh | sh
```

Then open a new terminal (or `source` the file the installer mentions) and run:

Install a specific version:

```sh
curl -fsSL https://raw.githubusercontent.com/justinvoicit/justinvoicit-cli/main/install.sh | JUSTINVOICIT_VERSION=v0.1.0 sh
```

To upgrade, run the install command again.
```sh
curl -fsSL https://raw.githubusercontent.com/justinvoicit/justinvoicit-cli/main/install.sh | sh
```

### Releasing

1. Bump `Justinvoicit::VERSION` in `lib/justinvoicit/version.rb`.
2. Commit, then tag and push: `git tag v0.1.0 && git push origin v0.1.0`.
3. Create a GitHub Release for the tag. The installer picks up the latest release.
