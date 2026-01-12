#!/bin/bash
set -e

# Directory for certs
DIR="./config/certs"
mkdir -p "$DIR"

echo "Generating generic self-signed certificates for workshop..."

# 1. Generate CA (Certificate Authority)
# This represents the entity trusting the server.
openssl req -new -x509 -days 3650 -nodes \
  -keyout "$DIR/ca.key" -out "$DIR/ca.crt" \
  -subj "/O=MQTT Workshop/CN=MQTT CA"

# 2. Generate Server Private Key
# This stays on the server and must be kept secret.
openssl genrsa -out "$DIR/server.key" 2048

# 3. Generate Certificate Signing Request (CSR)
# We use the IP address (or hostname) of the server.
# For a workshop, we'll just use "mqtt-broker" or a wildcard if simple.
# To keep it very simple for 'boring' crypto, we'll just set CN=mqtt-broker.
openssl req -new -key "$DIR/server.key" -out "$DIR/server.csr" \
  -subj "/O=MQTT Workshop/CN=mqtt-broker"

# 4. Sign the Server Certificate with our CA
openssl x509 -req -in "$DIR/server.csr" \
  -CA "$DIR/ca.crt" -CAkey "$DIR/ca.key" -CAcreateserial \
  -out "$DIR/server.crt" -days 365

# Cleanup
rm "$DIR/server.csr"
chmod 644 "$DIR/server.crt" "$DIR/ca.crt"
chmod 600 "$DIR/server.key" "$DIR/ca.key"

echo "------------------------------------------------"
echo "Certificates created in $DIR:"
ls -1 $DIR
echo "------------------------------------------------"
