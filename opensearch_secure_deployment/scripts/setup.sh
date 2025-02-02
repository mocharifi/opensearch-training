#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source the config to make sure variables are available to this script if needed
source "$ROOT_DIR/.env"

# 1. Validate prerequisites
"$SCRIPT_DIR/utils/validation-utils.sh" validate_prerequisites

# 2. Create the Docker network
"$SCRIPT_DIR/utils/network-utils.sh" create

# 3. Generate TLS certificates
"$SCRIPT_DIR/cert/generate-certs.sh" "${OS_NODE_COUNT}"

# 4. Generate configuration files for each OpenSearch node and Dashboards
"$SCRIPT_DIR/utils/configuration-utils.sh" "${OS_NODE_COUNT}"

# 5. Generate docker-compose.yml
"$SCRIPT_DIR/utils/generate-compose.sh" "${OS_NODE_COUNT}"

# 6. Launch the cluster
cd "$ROOT_DIR/docker"
docker-compose up -d

# 7. Cleanup certificates
"$SCRIPT_DIR/cert/cleanup-certs.sh"

# 8. Wait for the cluster to become healthy
"$SCRIPT_DIR/utils/validation-utils.sh" wait_for_cluster_ready