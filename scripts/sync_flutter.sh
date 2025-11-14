#!/usr/bin/env bash
set -euo pipefail

SRC=${FLUTTER_SRC:-$HOME/opt/flutter}
DEST=.flutter-sdk/flutter

if [[ ! -d "$SRC" ]]; then
  echo "Flutter source directory '$SRC' not found" >&2
  exit 1
fi

mkdir -p "$(dirname "$DEST")"
rsync -a --delete "$SRC/" "$DEST/"
