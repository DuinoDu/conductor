#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION=${FLUTTER_VERSION:-3.24.0}
FLUTTER_CHANNEL=${FLUTTER_CHANNEL:-stable}


if [[ "$(uname)" != "Linux" ]]; then
    sudo snap install flutter --classic

elif [[ "$(uname)" != "Darwin" ]]; then
    ARCH=$(uname -m)
    if [[ "$ARCH" == "arm64" ]]; then
      FLUTTER_ARCH=arm64
    else
      FLUTTER_ARCH=x64
    fi
    
    TMP_DIR=$(mktemp -d)
    cd "$TMP_DIR"
    ZIP_NAME="flutter_macos_${FLUTTER_ARCH}_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.zip"
    DOWNLOAD_URL="https://storage.googleapis.com/flutter_infra_release/releases/${FLUTTER_CHANNEL}/macos/${ZIP_NAME}"
    
    echo "Downloading Flutter ${FLUTTER_VERSION}-${FLUTTER_CHANNEL} (${FLUTTER_ARCH})..."
    curl -fLO "$DOWNLOAD_URL"
    
    echo "Unzipping..."
    unzip -q "$ZIP_NAME"
    
    echo "Installing to /usr/local/flutter ..."
    sudo rm -rf /usr/local/flutter
    sudo mv flutter /usr/local/flutter
    
    cd - >/dev/null
    rm -rf "$TMP_DIR"
    
    echo "Flutter installed. Add to PATH if not already:"
    echo 'export PATH="/usr/local/flutter/bin:$PATH"' >> ~/.my_profile
    
    echo "Run 'source ~/.zshrc' and 'flutter doctor' to finish setup."
fi
