#!/bin/bash
set -euo pipefail

# Directory for certs
DIR="./config/certs"
mkdir -p "$DIR"
CERTS_DIR="$(cd "$DIR" && pwd)"

# Certificate identity defaults (override via env vars if needed)
CERT_CN="${CERT_CN:-localhost}"
CERT_SAN_DNS_1="${CERT_SAN_DNS_1:-localhost}"
CERT_SAN_DNS_2="${CERT_SAN_DNS_2:-mqtt-broker}"
CERT_SAN_IP_1="${CERT_SAN_IP_1:-127.0.0.1}"
CERT_SAN_IP_2="${CERT_SAN_IP_2:-::1}"

echo "Generating generic self-signed certificates for workshop..."

# 1. Generate CA (Certificate Authority)
# This represents the entity trusting the server.
# NOTE: ca.key is the CA private key. Keep it safe and do not share it.
# Anyone with this key can issue certificates trusted by your CA.
# It is stored in $DIR (which is mounted into the container) for convenience
# in this workshop setup; in production, store it outside the repo and
# delete it after signing the server certificate.
openssl req -new -x509 -days 3650 -nodes \
  -keyout "$DIR/ca.key" -out "$DIR/ca.crt" \
  -subj "/O=MQTT Workshop/CN=MQTT CA"

# 2. Generate Server Private Key
# This stays on the server and must be kept secret.
openssl genrsa -out "$DIR/server.key" 2048

# 3. Generate Certificate Signing Request (CSR)
# Use localhost-friendly defaults so local WSS clients can validate hostnames.
openssl req -new -key "$DIR/server.key" -out "$DIR/server.csr" \
  -subj "/O=MQTT Workshop/CN=$CERT_CN"

cat > "$DIR/server.ext" <<EOF
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=DNS:$CERT_SAN_DNS_1,DNS:$CERT_SAN_DNS_2,IP:$CERT_SAN_IP_1,IP:$CERT_SAN_IP_2
EOF

# 4. Sign the Server Certificate with our CA
openssl x509 -req -in "$DIR/server.csr" \
  -CA "$DIR/ca.crt" -CAkey "$DIR/ca.key" -CAcreateserial \
  -out "$DIR/server.crt" -days 365 \
  -extfile "$DIR/server.ext"

# Cleanup
rm "$DIR/server.csr" "$DIR/server.ext"
chmod 644 "$DIR/server.crt" "$DIR/ca.crt"
chmod 600 "$DIR/server.key" "$DIR/ca.key"

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  docker run --rm --user 0:0 \
    -v "$CERTS_DIR:/certs" \
    eclipse-mosquitto:2 \
    sh -eu -c '
      chown 1883:1883 /certs/server.key
      chmod 600 /certs/server.key
    '
else
  echo "WARNING: Docker is not available, so server.key ownership was not aligned for the Mosquitto container user."
  echo "         If the broker cannot start, fix it with:"
  echo "         docker run --rm --user 0:0 -v \"$CERTS_DIR:/certs\" eclipse-mosquitto:2 sh -eu -c 'chown 1883:1883 /certs/server.key && chmod 600 /certs/server.key'"
fi

echo "------------------------------------------------"
echo "Certificates created in $DIR:"
ls -1 "$DIR"
echo "------------------------------------------------"
echo "IMPORTANT:"
echo "You must download '$DIR/ca.crt' to your local machine"
echo "to connect securely using MQTT Explorer or other clients."
echo "If hostname mismatch occurs, regenerate with env overrides:"
echo "CERT_CN=<host> CERT_SAN_DNS_1=<host> ./scripts/generate-certs.sh"
echo "------------------------------------------------"
