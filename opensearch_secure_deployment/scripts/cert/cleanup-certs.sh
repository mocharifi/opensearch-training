#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="$SCRIPT_DIR/../../deploy/certificates"

pushd "$CERTS_DIR" >/dev/null

echo "[INFO] Cleaning up temporary certificate files..."
rm -f *temp.pem *.csr *.ext

popd >/dev/null
echo "[INFO] Cleanup complete!"