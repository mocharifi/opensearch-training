#!/usr/bin/env bash
# Dynamically builds a docker-compose.yml based on OS_NODE_COUNT.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../.env"

OS_NODE_COUNT="${1:-$OS_NODE_COUNT}"
TEMPLATE_FILE="$SCRIPT_DIR/../../docker/docker-compose.yml.template"
OUTPUT_FILE="$SCRIPT_DIR/../../docker/docker-compose.yml"

echo "[INFO] Generating docker-compose.yml for ${OS_NODE_COUNT} node(s)..."

SERVICES_BLOCK=""
VOLUMES_BLOCK=""

for (( i = 1; i <= OS_NODE_COUNT; i++ )); do
  idx="$(printf "%02d" "$i")"
  NODE_NAME="${NODE_PREFIX}-${idx}"
  ip_suffix=$((10 + i))  # e.g. node 1 => .11, node 2 => .12, etc.

  SERVICES_BLOCK+="  ${NODE_NAME}:\n"
  SERVICES_BLOCK+="    image: opensearchproject/opensearch:${OPENSEARCH_VERSION}\n"
  SERVICES_BLOCK+="    container_name: ${NODE_NAME}\n"
  SERVICES_BLOCK+="    environment:\n"
  SERVICES_BLOCK+="      - OPENSEARCH_JAVA_OPTS=${OPENSEARCH_JAVA_OPTS}\n"
  SERVICES_BLOCK+="    ulimits:\n"
  SERVICES_BLOCK+="      memlock:\n"
  SERVICES_BLOCK+="        soft: -1\n"
  SERVICES_BLOCK+="        hard: -1\n"
  SERVICES_BLOCK+="      nofile:\n"
  SERVICES_BLOCK+="        soft: 65536\n"
  SERVICES_BLOCK+="        hard: 65536\n"
  SERVICES_BLOCK+="    networks:\n"
  SERVICES_BLOCK+="      opensearch-net:\n"
  SERVICES_BLOCK+="        ipv4_address: 172.20.0.${ip_suffix}\n"
  SERVICES_BLOCK+="    volumes:\n"
  SERVICES_BLOCK+="      - data-${NODE_NAME}:/usr/share/opensearch/data\n"
  SERVICES_BLOCK+="      - type: bind\n"
  SERVICES_BLOCK+="        source: ../deploy/configs/${NODE_NAME}.yml\n"
  SERVICES_BLOCK+="        target: /usr/share/opensearch/config/opensearch.yml\n"
  SERVICES_BLOCK+="      - type: bind\n"
  SERVICES_BLOCK+="        source: ../deploy/certificates/root-ca.pem\n"
  SERVICES_BLOCK+="        target: /usr/share/opensearch/config/root-ca.pem\n"
  SERVICES_BLOCK+="      - type: bind\n"
  SERVICES_BLOCK+="        source: ../deploy/certificates/${NODE_NAME}.pem\n"
  SERVICES_BLOCK+="        target: /usr/share/opensearch/config/${NODE_NAME}.pem\n"
  SERVICES_BLOCK+="      - type: bind\n"
  SERVICES_BLOCK+="        source: ../deploy/certificates/${NODE_NAME}-key.pem\n"
  SERVICES_BLOCK+="        target: /usr/share/opensearch/config/${NODE_NAME}-key.pem\n"
  SERVICES_BLOCK+="    ports:\n"
  SERVICES_BLOCK+="      - \"920${i}:9200\"\n"
  SERVICES_BLOCK+="      - \"960${i}:9600\"\n\n"

  VOLUMES_BLOCK+="  data-${NODE_NAME}: {}\n"
done

# Add Dashboards service
DASHBOARDS_BLOCK=""
DASHBOARDS_BLOCK+="  os-dashboards-01:\n"
DASHBOARDS_BLOCK+="    image: opensearchproject/opensearch-dashboards:${DASHBOARD_VERSION}\n"
DASHBOARDS_BLOCK+="    container_name: os-dashboards-01\n"
DASHBOARDS_BLOCK+="    environment:\n"
DASHBOARDS_BLOCK+="      - OPENSEARCH_HOSTS=[\"https://172.20.0.11:9200\""
for (( i = 2; i <= OS_NODE_COUNT; i++ )); do
  ip_suffix=$((10 + i))
  DASHBOARDS_BLOCK+=",\"https://172.20.0.${ip_suffix}:9200\""
done
DASHBOARDS_BLOCK+="]\n"
DASHBOARDS_BLOCK+="    networks:\n"
DASHBOARDS_BLOCK+="      opensearch-net:\n"
DASHBOARDS_BLOCK+="        ipv4_address: 172.20.0.10\n"
DASHBOARDS_BLOCK+="    volumes:\n"
DASHBOARDS_BLOCK+="      - type: bind\n"
DASHBOARDS_BLOCK+="        source: ../deploy/configs/opensearch_dashboards.yml\n"
DASHBOARDS_BLOCK+="        target: /usr/share/opensearch-dashboards/config/opensearch_dashboards.yml\n"
DASHBOARDS_BLOCK+="      - type: bind\n"
DASHBOARDS_BLOCK+="        source: ../deploy/certificates/root-ca.pem\n"
DASHBOARDS_BLOCK+="        target: /usr/share/opensearch-dashboards/config/root-ca.pem\n"
DASHBOARDS_BLOCK+="      - type: bind\n"
DASHBOARDS_BLOCK+="        source: ../deploy/certificates/os-dashboards-01.pem\n"
DASHBOARDS_BLOCK+="        target: /usr/share/opensearch-dashboards/config/os-dashboards-01.pem\n"
DASHBOARDS_BLOCK+="      - type: bind\n"
DASHBOARDS_BLOCK+="        source: ../deploy/certificates/os-dashboards-01-key.pem\n"
DASHBOARDS_BLOCK+="        target: /usr/share/opensearch-dashboards/config/os-dashboards-01-key.pem\n"
DASHBOARDS_BLOCK+="    ports:\n"
DASHBOARDS_BLOCK+="      - \"5601:5601\"\n\n"

SERVICES_BLOCK+="${DASHBOARDS_BLOCK}"

# Substitute placeholders in the docker-compose template
sed -e "s|{{OS_NODES}}|${SERVICES_BLOCK}|g" \
    -e "s|{{OS_VOLUMES}}|${VOLUMES_BLOCK}|g" \
    -e "s|{{NETWORK_NAME}}|${NETWORK_NAME}|g" \
    "$TEMPLATE_FILE" \
    > "$OUTPUT_FILE"

echo "[INFO] Generated docker-compose.yml for ${OS_NODE_COUNT} node(s)."