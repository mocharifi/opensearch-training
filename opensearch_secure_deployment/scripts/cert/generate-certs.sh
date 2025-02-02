#!/usr/bin/env bash
#
# Generates TLS certificates for OpenSearch and Dashboards.

set -euo pipefail

# Determine the script directory and source the central configuration.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../.env"

# Allow OS_NODE_COUNT to be passed as an argument, or use the value from .env.
OS_NODE_COUNT="${1:-$OS_NODE_COUNT}"
CERTS_DIR="$SCRIPT_DIR/../../deploy/certificates"

mkdir -p "$CERTS_DIR"
pushd "$CERTS_DIR" >/dev/null

echo "[INFO] Generating certificates in $CERTS_DIR for ${OS_NODE_COUNT} node(s)..."

# 1. Root CA
openssl genrsa -out root-ca-key.pem 2048
openssl req -new -x509 -sha256 -key root-ca-key.pem \
  -subj "/C=${CERT_COUNTRY}/ST=${CERT_STATE}/L=${CERT_LOCALITY}/O=${CERT_ORG}/OU=${CERT_ORG_UNIT}/CN=${ROOT_COMMON_NAME}" \
  -out root-ca.pem -days 730

# 2. Admin certificate
openssl genrsa -out admin-key-temp.pem 2048
openssl pkcs8 -inform PEM -outform PEM -in admin-key-temp.pem -topk8 \
  -nocrypt -v1 PBE-SHA1-3DES -out admin-key.pem
openssl req -new -key admin-key.pem \
  -subj "/C=${CERT_COUNTRY}/ST=${CERT_STATE}/L=${CERT_LOCALITY}/O=${CERT_ORG}/OU=${CERT_ORG_UNIT}/CN=${ADMIN_COMMON_NAME}" \
  -out admin.csr
openssl x509 -req -in admin.csr -CA root-ca.pem -CAkey root-ca-key.pem \
  -CAcreateserial -sha256 -out admin.pem -days 730

# 3. Create OpenSearch node certificates dynamically
for (( i=1; i <= OS_NODE_COUNT; i++ )); do
  idx=$(printf "%02d" "$i")
  NODE_NAME=$(printf "${NODE_PREFIX}-%s" "$idx")

  openssl genrsa -out "${NODE_NAME}-key-temp.pem" 2048
  openssl pkcs8 -inform PEM -outform PEM -in "${NODE_NAME}-key-temp.pem" \
    -topk8 -nocrypt -v1 PBE-SHA1-3DES -out "${NODE_NAME}-key.pem"

  openssl req -new -key "${NODE_NAME}-key.pem" \
    -subj "/C=${CERT_COUNTRY}/ST=${CERT_STATE}/L=${CERT_LOCALITY}/O=${CERT_ORG}/OU=${CERT_ORG_UNIT}/CN=${NODE_NAME}" \
    -out "${NODE_NAME}.csr"

  cat <<EOF > "${NODE_NAME}.ext"
subjectAltName=DNS:${NODE_NAME},DNS:localhost,IP:172.20.0.$((10 + i)),IP:127.0.0.1
EOF

  openssl x509 -req -in "${NODE_NAME}.csr" -CA root-ca.pem -CAkey root-ca-key.pem \
    -CAcreateserial -sha256 -out "${NODE_NAME}.pem" -days 730 \
    -extfile "${NODE_NAME}.ext"

  # Append the root CA certificate for trust chain.
  cat root-ca.pem >> "${NODE_NAME}.pem"
done

# 4. Create OpenSearch Dashboards certificate
openssl genrsa -out os-dashboards-01-key-temp.pem 2048
openssl pkcs8 -inform PEM -outform PEM -in os-dashboards-01-key-temp.pem \
  -topk8 -nocrypt -v1 PBE-SHA1-3DES -out os-dashboards-01-key.pem

openssl req -new -key os-dashboards-01-key.pem \
  -subj "/C=${CERT_COUNTRY}/ST=${CERT_STATE}/L=${CERT_LOCALITY}/O=${CERT_ORG}/OU=${CERT_ORG_UNIT}/CN=os-dashboards-01" \
  -out os-dashboards-01.csr

cat <<EOF > os-dashboards-01.ext
subjectAltName=DNS:os-dashboards-01,IP:172.20.0.10
EOF

openssl x509 -req -in os-dashboards-01.csr -CA root-ca.pem -CAkey root-ca-key.pem \
  -CAcreateserial -sha256 -out os-dashboards-01.pem -days 730 \
  -extfile os-dashboards-01.ext

popd >/dev/null
echo "[INFO] Certificate generation complete."