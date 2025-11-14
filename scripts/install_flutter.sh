#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/install_flutter.sh [options]

Options:
  --force       Reinstall even if a Flutter directory already exists.
  -h, --help    Show this help message.

Environment overrides:
  FLUTTER_HOME      Target directory for the Flutter SDK (default: <repo>/.flutter)
  FLUTTER_VERSION   Flutter version to install (default: 3.24.3)
  FLUTTER_CHANNEL   Release channel to install (default: stable)
EOF
}

log() {
  printf '[install_flutter] %s\n' "$*" >&2
}

fail() {
  log "Error: $*"
  exit 1
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "Missing required command: $1"
  fi
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
DEFAULT_HOME="$ROOT_DIR/.flutter"
FLUTTER_HOME="${FLUTTER_HOME:-$DEFAULT_HOME}"
FLUTTER_VERSION="${FLUTTER_VERSION:-3.24.3}"
FLUTTER_CHANNEL="${FLUTTER_CHANNEL:-stable}"
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      FORCE=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown option: $1"
      ;;
  esac
  shift
done

detect_platform() {
  local os arch
  os="$(uname -s)"
  arch="$(uname -m)"
  case "$os" in
    Darwin)
      PLATFORM="macos"
      case "$arch" in
        arm64)
          ARCHIVE_NAME="flutter_macos_arm64_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.zip"
          ;;
        x86_64|amd64)
          ARCHIVE_NAME="flutter_macos_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.zip"
          ;;
        *)
          fail "Unsupported macOS architecture: $arch"
          ;;
      esac
      ;;
    Linux)
      PLATFORM="linux"
      case "$arch" in
        x86_64|amd64)
          ARCHIVE_NAME="flutter_linux_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.tar.xz"
          ;;
        arm64|aarch64)
          ARCHIVE_NAME="flutter_linux_arm64_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.tar.xz"
          ;;
        *)
          fail "Unsupported Linux architecture: $arch"
          ;;
      esac
      ;;
    *)
      fail "Unsupported operating system: $os"
      ;;
  esac
  DOWNLOAD_URL="https://storage.googleapis.com/flutter_infra_release/releases/${FLUTTER_CHANNEL}/${PLATFORM}/${ARCHIVE_NAME}"
}

extract_archive() {
  local archive_path="$1"
  if [[ "$archive_path" == *.zip ]]; then
    require_cmd unzip
    unzip -q "$archive_path" -d "$TMP_DIR"
  else
    require_cmd tar
    tar -xf "$archive_path" -C "$TMP_DIR"
  fi
}

detect_platform
require_cmd curl

if [[ -d "$FLUTTER_HOME" ]]; then
  if [[ "$FORCE" -ne 1 ]]; then
    log "Flutter already installed at $FLUTTER_HOME (use --force to reinstall)."
    exit 0
  fi
  log "Removing existing Flutter installation at $FLUTTER_HOME"
  rm -rf "$FLUTTER_HOME"
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

ARCHIVE_PATH="$TMP_DIR/$ARCHIVE_NAME"
log "Downloading Flutter ${FLUTTER_VERSION}-${FLUTTER_CHANNEL} from $DOWNLOAD_URL"
curl -L "$DOWNLOAD_URL" -o "$ARCHIVE_PATH"

log "Extracting archive..."
extract_archive "$ARCHIVE_PATH"

if [[ ! -d "$TMP_DIR/flutter" ]]; then
  fail "Archive did not contain the Flutter directory."
fi

mkdir -p "$(dirname "$FLUTTER_HOME")"
mv "$TMP_DIR/flutter" "$FLUTTER_HOME"

BIN_PATH="$FLUTTER_HOME/bin"
log "Flutter installed at $FLUTTER_HOME"
if [[ ":${PATH}:" != *":${BIN_PATH}:"* ]]; then
  log "Add ${BIN_PATH} to your PATH, e.g.:"
  log "  export PATH=\"${BIN_PATH}:\$PATH\""
fi

log "Run 'flutter --version' to verify the installation."
