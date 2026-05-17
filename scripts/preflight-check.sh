#!/bin/sh
set -eu

# Validates that all required runtime files exist before starting the broker.
# Run this from the repository root before 'docker compose up'.
#
# Exit code 0 — all checks passed; safe to start.
# Exit code 1 — one or more required files are missing.

FAIL=0

check_file() {
  if [ ! -f "$1" ]; then
    echo "❌ Missing: $1"
    FAIL=1
  else
    echo "✅ Found:   $1"
  fi
}

echo "=== MQTT Broker Pre-flight Check ==="
echo ""

echo "--- Broker config ---"
check_file "config/passwords"
check_file "config/acl"

echo ""
echo "--- TLS certificates (self-signed or Let's Encrypt) ---"
# Detect which cert path is active in mosquitto.conf
if grep -q "letsencrypt" config/mosquitto.conf 2>/dev/null && \
   ! grep -q "^#.*letsencrypt" config/mosquitto.conf 2>/dev/null; then
  LE_DIR=$(grep "certfile" config/mosquitto.conf | grep -v "^#" | head -1 | awk '{print $2}')
  LE_KEY=$(grep "keyfile"  config/mosquitto.conf | grep -v "^#" | head -1 | awk '{print $2}')
  check_file "$LE_DIR"
  check_file "$LE_KEY"
else
  check_file "config/certs/ca.crt"
  check_file "config/certs/server.crt"
  check_file "config/certs/server.key"
fi

echo ""
if [ "$FAIL" -eq 1 ]; then
  echo "❌ Pre-flight check failed. Fix the missing files before starting the broker."
  echo "   See README.md for setup instructions."
  exit 1
fi

echo "✅ All required files present. Ready to start."
