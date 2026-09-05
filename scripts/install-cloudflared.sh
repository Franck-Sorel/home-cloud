#!/usr/bin/env bash
# install-cloudflared.sh
#
# Downloads & installs the `cloudflared` CLI client used to create/manage
# the Cloudflare Tunnel. The long-lived tunnel daemon runs as a k3s POD —
# this tool is only for one-time provisioning.
#
# Usage:   ./scripts/install-cloudflared.sh
# Doc:     docs/02-setup/02-cloudflare-tunnel.md
#
set -euo pipefail

VERSION="${CLOUDFLARED_VERSION:-latest}"
DEST="${CLOUDFLARED_DEST:-/usr/local/bin/cloudflared}"

echo "→ Installing cloudflared (${VERSION}) to ${DEST}"

if [[ "${VERSION}" == "latest" ]]; then
  url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"
else
  url="https://github.com/cloudflare/cloudflared/releases/download/${VERSION}/cloudflared-linux-amd64"
fi

tmp="$(mktemp)"
trap 'rm -f "${tmp}"' EXIT

curl -sSL -o "${tmp}" "${url}"
chmod +x "${tmp}"
sudo mv "${tmp}" "${DEST}"

cloudflared --version
echo "✓ cloudflared installed at ${DEST}"