#!/bin/bash

COMMAND="${1:-}"

validate_prerequisites() {
    echo "[INFO] Start Validation prerequisites..."
    # Check Docker
    if ! command -v docker &> /dev/null; then
        echo "Error: Docker is not installed"
        exit 1
    fi

    # Check Docker Compose
    if ! command -v docker compose &> /dev/null; then
        echo "Error: Docker Compose is not installed"
        exit 1
    fi

    # Check OpenSSL
    if ! command -v openssl &> /dev/null; then
        echo "Error: OpenSSL is not installed"
        exit 1
    fi
}

wait_for_cluster_ready() {
    echo "Waiting for cluster to be ready..."
    local retries=0
    local max_retries=5

    until curl -sk -u admin:admin https://localhost:9201/_cluster/health | grep -q '"status":"green"'; do
        [[ $retries -eq $max_retries ]] && {
            echo "Error: Cluster failed to reach healthy state"
            exit 1
        }
        echo -n "."
        sleep 5
        ((retries++))
    done

    echo "Cluster is healthy!"
}

case "$COMMAND" in
  validate_prerequisites)
    validate_prerequisites
    ;;
  wait_for_cluster_ready)
    wait_for_cluster_ready
    ;;
  *)
    echo "Usage: $0 {validate_prerequisites|wait_for_cluster_ready}"
    exit 1
    ;;
esac
