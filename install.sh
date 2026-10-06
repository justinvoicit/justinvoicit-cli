#!/usr/bin/env bash
# JustInvoicIt CLI installer

set -euo pipefail

echo "Hello, welcome to JustInvoicIt!"

REPO="justinvoicit/justinvoicit-cli"
BIN_DIR="${JUSTINVOICIT_BIN_DIR:-}"
VERSION="${JUSTINVOICIT_VERSION:-}"
CURL_SCHANNEL_FALLBACK_FLAG=""
CURL_LAST_ERROR=""
CURL_FALLBACK_NOTED=0

default_bin_dir() {
  local platform="$1"

  if [[ "$platform" == windows_* ]]; then
    echo "$HOME/bin"
  else
    echo "$HOME/.local/bin"
  fi
}

detect_platform() {
  local os arch

  os=$(uname -s | tr '[:upper:]' '[:lower:]')
  case "$os" in
    darwin) os="darwin" ;;
    linux) os="linux" ;;
    freebsd) os="freebsd" ;;
    openbsd) os="openbsd" ;;
    mingw*|msys*|cygwin*) os="windows" ;;
    *) echo "Unsupported OS: $os" >&2; exit 1 ;;
  esac

  arch=$(uname -m)
  case "$arch" in
    x86_64|amd64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) echo "Unsupported architecture: $arch" >&2; exit 1 ;;
  esac

  echo "${os}_${arch}"
}

main() {
  # Check for curl
  if ! command -v curl &>/dev/null; then
    echo "curl is required but not installed" >&2
    exit 1
  fi

  local platform
  platform=$(detect_platform)

  if [[ -z "$BIN_DIR" ]]; then
    BIN_DIR=$(default_bin_dir "$platform")
  fi

  echo "Platform: $platform"
  echo "Install dir: $BIN_DIR"
}

main "$@"
