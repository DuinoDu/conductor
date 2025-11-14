#!/usr/bin/env bash

# Create a starter ~/.conductor/config.yaml without clobbering an existing one.
set -euo pipefail

CONFIG_DIR="${HOME}/.conductor"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -f "${CONFIG_FILE}" ]]; then
  echo "Config already exists at ${CONFIG_FILE}; aborting."
  exit 1
fi

mkdir -p "${CONFIG_DIR}"

cat > "${CONFIG_FILE}" <<EOF
agent_token: local-dev-token
backend_url: http://127.0.0.1:4000
websocket_url: ws://127.0.0.1:4000/ws/agent
projects: []

EOF

echo "Wrote starter config to ${CONFIG_FILE}"
