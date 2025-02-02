#!/usr/bin/env bash
#
# Generates per-node OpenSearch configs and a single Dashboards config.

set -euo pipefail

# Determine the script directory and load central configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../.env"

# Allow OS_NODE_COUNT to be overridden as the first argument
OS_NODE_COUNT="${1:-$OS_NODE_COUNT}"
CONFIGS_DIR="$SCRIPT_DIR/../../deploy/configs"

echo "[INFO] Generating OpenSearch configuration files for ${OS_NODE_COUNT} node(s)..."

# -------------------------------------------------------------------
# Dynamically generate the list of initial master nodes and discovery seed hosts.
# These lists will be generated based on the OS_NODE_COUNT value.
# -------------------------------------------------------------------
INITIAL_MASTER_NODES=""
DISCOVERY_SEED_HOSTS=""

for (( i=1; i<=OS_NODE_COUNT; i++ )); do
  node=$(printf "${NODE_PREFIX}-%02d" "$i")
  INITIAL_MASTER_NODES+="\"${node}\","
  DISCOVERY_SEED_HOSTS+="\"${node}\","
done
# Remove trailing commas
INITIAL_MASTER_NODES="${INITIAL_MASTER_NODES%,}"
DISCOVERY_SEED_HOSTS="${DISCOVERY_SEED_HOSTS%,}"

# -------------------------------------------------------------------
# Generate the NODES_DN block for certificate subject details.
# Each node will have a subject built from the certificate variables.
# -------------------------------------------------------------------
NODES_DN=""
for (( i=1; i<=OS_NODE_COUNT; i++ )); do
  node=$(printf "${NODE_PREFIX}-%02d" "$i")
  NODES_DN+="  - \"CN=${node},OU=${CERT_ORG_UNIT},O=${CERT_ORG},L=${CERT_LOCALITY},ST=${CERT_STATE},C=${CERT_COUNTRY}\"\n"
done

# -------------------------------------------------------------------
# For each OpenSearch node, generate a configuration file by replacing
# placeholders in the opensearch.yml.template.
# -------------------------------------------------------------------
for (( i=1; i<=OS_NODE_COUNT; i++ )); do
  NODE_NAME=$(printf "${NODE_PREFIX}-%02d" "$i")
  output_file="$CONFIGS_DIR/${NODE_NAME}.yml"

  sed \
    -e "s|{{CLUSTER_NAME}}|${CLUSTER_NAME}|g" \
    -e "s|{{NODE_NAME}}|${NODE_NAME}|g" \
    -e "s|{{NETWORK_HOST}}|${NETWORK_HOST}|g" \
    -e "s|{{BOOTSTRAP_MEMORY_LOCK}}|${BOOTSTRAP_MEMORY_LOCK}|g" \
    -e "s|{{INITIAL_MASTER_NODES}}|[${INITIAL_MASTER_NODES}]|g" \
    -e "s|{{DISCOVERY_SEED_HOSTS}}|[${DISCOVERY_SEED_HOSTS}]|g" \
    -e "s|{{ADMIN_COMMON_NAME}}|${ADMIN_COMMON_NAME}|g" \
    -e "s|{{CERT_ORG_UNIT}}|${CERT_ORG_UNIT}|g" \
    -e "s|{{CERT_ORG}}|${CERT_ORG}|g" \
    -e "s|{{CERT_LOCALITY}}|${CERT_LOCALITY}|g" \
    -e "s|{{CERT_STATE}}|${CERT_STATE}|g" \
    -e "s|{{CERT_COUNTRY}}|${CERT_COUNTRY}|g" \
    -e "s|{{NODES_DN}}|${NODES_DN}|g" \
    "$CONFIGS_DIR/opensearch.yml.template" \
    > "$output_file"

  echo "[INFO] Created ${output_file}"
done

# -------------------------------------------------------------------
# Generate the Dashboards configuration file.
# This uses a dynamic list of OpenSearch hosts based on the node IP pattern.
# -------------------------------------------------------------------
echo "[INFO] Generating OpenSearch Dashboards configuration..."
ALL_HOSTS=""
for (( i=1; i<=OS_NODE_COUNT; i++ )); do
  # Assuming the IP addresses are constructed as 172.20.0.(10 + i)
  ip_suffix=$((10 + i))
  ALL_HOSTS+="\"https://172.20.0.${ip_suffix}:9200\","
done
# Remove the trailing comma
ALL_HOSTS="${ALL_HOSTS%,}"

sed -e "s|{{OPENSEARCH_HOSTS}}|${ALL_HOSTS}|g" \
    -e "s|{{DASHBOARD_SERVER_NAME}}|${DASHBOARD_SERVER_NAME}|g" \
    -e "s|{{DASHBOARD_USERNAME}}|${DASHBOARD_USERNAME}|g" \
    -e "s|{{DASHBOARD_PASSWORD}}|${DASHBOARD_PASSWORD}|g" \
    "$CONFIGS_DIR/dashboards.yml.template" \
    > "$CONFIGS_DIR/opensearch_dashboards.yml"

echo "[INFO] Done generating configuration files."