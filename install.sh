#!/bin/sh
# JustInvoicIt CLI installer
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/justinvoicit/justinvoicit-cli/main/install.sh | sh
#
# Requires Ruby (>= MIN_RUBY below). Installs the CLI source into ~/.justinvoicit,
# installs its gems there with Bundler, and puts a `justinvoicit` command on PATH.
#
# Options (environment variables):
#   JUSTINVOICIT_VERSION           Git tag to install, e.g. v1.2.0 (default: latest release,
#                                  or the default branch if there are no releases)
#   JUSTINVOICIT_HOME              Install root (default: $HOME/.justinvoicit)
#   JUSTINVOICIT_NO_MODIFY_PATH=1  Don't touch shell rc files
#
# Example:
#   curl -fsSL https://raw.githubusercontent.com/justinvoicit/justinvoicit-cli/main/install.sh | JUSTINVOICIT_VERSION=v1.2.0 sh

set -eu

REPO="justinvoicit/justinvoicit-cli"
DEFAULT_BRANCH="main"
BIN_NAME="justinvoicit"
MIN_RUBY="3.0.0"

JI_HOME="${JUSTINVOICIT_HOME:-$HOME/.justinvoicit}"
BIN_DIR="$JI_HOME/bin"
VERSION="${JUSTINVOICIT_VERSION:-latest}"

# ---------- output helpers ----------

if [ -t 1 ]; then
  BOLD="$(printf '\033[1m')"; GREEN="$(printf '\033[32m')"
  YELLOW="$(printf '\033[33m')"; RED="$(printf '\033[31m')"; RESET="$(printf '\033[0m')"
else
  BOLD=""; GREEN=""; YELLOW=""; RED=""; RESET=""
fi

info()  { printf '%s==>%s %s\n' "$BOLD" "$RESET" "$*"; }
warn()  { printf '%swarning:%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }
error() { printf '%serror:%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || error "'$1' is required but not installed."; }

# ---------- download helpers (curl or wget) ----------

download() {
  # download <url> <output-file>
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --retry 3 -o "$2" "$1"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$2" "$1"
  else
    error "either 'curl' or 'wget' is required."
  fi
}

fetch() {
  # fetch <url>  -> prints body to stdout
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1"
  else
    wget -q -O - "$1"
  fi
}

# ---------- Ruby checks ----------

ruby_install_hint() {
  cat >&2 <<EOF

Install Ruby $MIN_RUBY or newer, then re-run this installer. For example:
  macOS:          brew install ruby
  Ubuntu/Debian:  sudo apt-get install -y ruby-full build-essential
  Any (rbenv):    https://github.com/rbenv/rbenv#installation
EOF
  exit 1
}

check_ruby() {
  if ! command -v ruby >/dev/null 2>&1; then
    printf '%serror:%s Ruby is not installed.\n' "$RED" "$RESET" >&2
    ruby_install_hint
  fi

  # Resolve the real interpreter, not an rbenv/asdf shim, so the CLI keeps
  # working with the gems it was installed with even if the user switches Ruby.
  RUBY="$(ruby -e 'print RbConfig.ruby')"
  ruby_version="$("$RUBY" -e 'print RUBY_VERSION')"

  if ! "$RUBY" -e 'exit(Gem::Version.new(RUBY_VERSION) >= Gem::Version.new(ARGV[0]))' -- "$MIN_RUBY"; then
    printf '%serror:%s Ruby %s found, but %s or newer is required.\n' "$RED" "$RESET" "$ruby_version" "$MIN_RUBY" >&2
    ruby_install_hint
  fi

  if ! "$RUBY" -e 'Gem.bin_path("bundler", "bundle")' >/dev/null 2>&1; then
    info "Installing Bundler"
    "$RUBY" -S gem install --user-install --no-document bundler || \
      error "could not install Bundler. Try: gem install bundler"
  fi

  info "Using Ruby $ruby_version ($RUBY)"
}

bundle() {
  # Run Bundler with the resolved Ruby. `--` stops Ruby from eating the args.
  "$RUBY" -e 'load Gem.bin_path("bundler", "bundle")' -- "$@"
}

# ---------- resolve which version to install ----------

resolve_version() {
  if [ "$VERSION" != "latest" ]; then
    REF="$VERSION"
    TARBALL_URL="https://github.com/$REPO/archive/refs/tags/$VERSION.tar.gz"
    return 0
  fi

  tag="$(fetch "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null \
    | grep '"tag_name"' | head -n 1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')" || true

  if [ -n "$tag" ]; then
    REF="$tag"
    TARBALL_URL="https://github.com/$REPO/archive/refs/tags/$tag.tar.gz"
  else
    warn "no published release found, installing from the '$DEFAULT_BRANCH' branch"
    REF="$DEFAULT_BRANCH"
    TARBALL_URL="https://github.com/$REPO/archive/refs/heads/$DEFAULT_BRANCH.tar.gz"
  fi
}

# ---------- PATH setup ----------

add_to_path() {
  case ":$PATH:" in
    *":$BIN_DIR:"*) return 0 ;; # already on PATH
  esac

  if [ "${JUSTINVOICIT_NO_MODIFY_PATH:-0}" = "1" ]; then
    warn "$BIN_DIR is not on your PATH. Add it manually:"
    printf '    export PATH="%s:$PATH"\n' "$BIN_DIR"
    return 0
  fi

  shell_name="$(basename "${SHELL:-sh}")"
  case "$shell_name" in
    zsh)  rc="${ZDOTDIR:-$HOME}/.zshrc";  line="export PATH=\"$BIN_DIR:\$PATH\"" ;;
    bash) rc="$HOME/.bashrc"
          [ "$(uname -s)" = "Darwin" ] && rc="$HOME/.bash_profile"
          line="export PATH=\"$BIN_DIR:\$PATH\"" ;;
    fish) rc="$HOME/.config/fish/config.fish"; line="fish_add_path \"$BIN_DIR\"" ;;
    *)    rc="$HOME/.profile"; line="export PATH=\"$BIN_DIR:\$PATH\"" ;;
  esac

  mkdir -p "$(dirname "$rc")"
  if ! grep -qsF "$BIN_DIR" "$rc"; then
    printf '\n# justinvoicit\n%s\n' "$line" >> "$rc"
    info "Added $BIN_DIR to PATH in $rc"
  fi
  RESTART_HINT="$rc"
}

# ---------- main ----------

main() {
  need tar
  check_ruby
  resolve_version

  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT INT TERM

  info "Downloading $BIN_NAME ($REF)"
  download "$TARBALL_URL" "$tmp/src.tar.gz" || \
    error "download failed: $TARBALL_URL
       Check that '$REF' exists: https://github.com/$REPO/releases"

  mkdir -p "$tmp/src"
  tar -xzf "$tmp/src.tar.gz" -C "$tmp/src" --strip-components=1
  [ -f "$tmp/src/bin/$BIN_NAME" ] || error "bin/$BIN_NAME not found in $REF"

  # Install into a fresh directory, then switch over, so a failed install
  # never breaks a working one.
  app_dir="$JI_HOME/versions/$REF"
  rm -rf "$app_dir.new"
  mkdir -p "$JI_HOME/versions"
  mv "$tmp/src" "$app_dir.new"

  if [ -f "$app_dir.new/Gemfile" ]; then
    info "Installing gem dependencies"
    (
      cd "$app_dir.new"
      bundle config set --local path vendor/bundle >/dev/null
      bundle config set --local without 'development test' >/dev/null
      bundle install --jobs 4 --retry 3 --quiet
    ) || {
      rm -rf "$app_dir.new"
      error "bundle install failed. Gems with native extensions need build tools
       (Ubuntu/Debian: sudo apt-get install -y build-essential ruby-dev; macOS: xcode-select --install)"
    }
  fi

  rm -rf "$app_dir"
  mv "$app_dir.new" "$app_dir"
  ln -sfn "$app_dir" "$JI_HOME/current"

  # Remove older versions
  for dir in "$JI_HOME"/versions/*; do
    [ "$dir" = "$app_dir" ] || rm -rf "$dir"
  done

  # Wrapper that runs the CLI with the Ruby and gems it was installed with
  mkdir -p "$BIN_DIR"
  app="$JI_HOME/current"
  if [ -f "$app_dir/Gemfile" ]; then
    run_cmd="BUNDLE_GEMFILE=\"$app/Gemfile\" exec \"$RUBY\" -rbundler/setup \"$app/bin/$BIN_NAME\" \"\$@\""
  else
    run_cmd="exec \"$RUBY\" -I \"$app/lib\" \"$app/bin/$BIN_NAME\" \"\$@\""
  fi
  cat > "$BIN_DIR/$BIN_NAME" <<EOF
#!/bin/sh
# Generated by the justinvoicit installer. Re-run the installer to upgrade.
if [ ! -x "$RUBY" ]; then
  echo "justinvoicit: Ruby at $RUBY is gone. Re-run the installer:" >&2
  echo "  curl -fsSL https://raw.githubusercontent.com/$REPO/$DEFAULT_BRANCH/install.sh | sh" >&2
  exit 1
fi
$run_cmd
EOF
  chmod +x "$BIN_DIR/$BIN_NAME"

  RESTART_HINT=""
  add_to_path

  printf '\n%s%s %s was installed to %s%s\n' "$GREEN" "$BIN_NAME" "$REF" "$BIN_DIR/$BIN_NAME" "$RESET"

  printf '\nGet started:\n'
  if [ -n "$RESTART_HINT" ]; then
    printf '    source %s   # or open a new terminal\n' "$RESTART_HINT"
  fi
  printf '    %s login\n' "$BIN_NAME"
  printf '    %s --help\n\n' "$BIN_NAME"
}

main "$@"
