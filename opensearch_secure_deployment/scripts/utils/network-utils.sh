#!/usr/bin/env bash
set -euo pipefail

COMMAND="${1:-}"
NETWORK_NAME="opensearch-dev-net"
SUBNET="172.20.0.0/16"

create_network() {
  docker network create --subnet="$SUBNET" "$NETWORK_NAME" 2>/dev/null || {
    echo "[WARN] Network '$NETWORK_NAME' already exists, skipping."
  }
}

remove_network() {
  docker network rm "$NETWORK_NAME" 2>/dev/null || {
    echo "[WARN] Network '$NETWORK_NAME' not found or cannot remove."
  }
}

case "$COMMAND" in
  create)
    create_network
    ;;
  remove)
    remove_network
    ;;
  *)
    echo "Usage: $0 {create|remove}"
    exit 1
    ;;
esac