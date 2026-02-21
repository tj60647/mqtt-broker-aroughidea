#!/bin/bash
set -euo pipefail

# WSS smoke test for deployment validation.
# Validates:
# 1) TLS handshake on WebSocket listener
# 2) Authenticated subscribe/publish over wss://

USER_NAME="${MQTT_USER:-workshop-user}"
PASSWORD="${MQTT_PASS:-mqtt-fun-2026}"
HOST="${MQTT_HOST:-localhost}"
PORT="${MQTT_WSS_PORT:-9001}"
TOPIC="${MQTT_TOPIC:-test/healthcheck}"
MESSAGE="${MQTT_MESSAGE:-HELLO_WSS}"
CA_FILE="${MQTT_CA_FILE:-$PWD/config/certs/ca.crt}"
SUB_NAME="mqtt-wss-tester-sub"

cleanup() {
  docker stop "$SUB_NAME" > /dev/null 2>&1 || true
}

trap cleanup EXIT

if [ ! -f "$CA_FILE" ]; then
  echo "❌ FAILURE: CA file not found at: $CA_FILE"
  echo "   Generate certs first: ./scripts/generate-certs.sh"
  exit 1
fi

echo "----------------------------------------------------------------"
echo "Testing Secure WebSockets (WSS) on $HOST:$PORT"
echo "----------------------------------------------------------------"

echo "[1/4] TLS handshake check with OpenSSL..."
if openssl s_client -connect "$HOST:$PORT" -servername "$HOST" -CAfile "$CA_FILE" < /dev/null > /tmp/mqtt-wss-openssl.log 2>&1; then
  echo "✅ TLS handshake succeeded"
else
  echo "❌ FAILURE: TLS handshake failed"
  echo "   Check certs/listener with: docker logs mosquitto"
  echo "   OpenSSL output:"
  tail -n 20 /tmp/mqtt-wss-openssl.log || true
  exit 1
fi

echo "[2/4] Starting authenticated WSS subscriber..."
docker run --name "$SUB_NAME" --rm -d --network host \
  -v "$CA_FILE:/certs/ca.crt:ro" \
  eclipse-mosquitto:2 \
  mosquitto_sub -L "wss://$USER_NAME:$PASSWORD@$HOST:$PORT/$TOPIC" --cafile /certs/ca.crt -v > /dev/null

sleep 2

echo "[3/4] Publishing authenticated WSS message '$MESSAGE'..."
docker run --rm --network host \
  -v "$CA_FILE:/certs/ca.crt:ro" \
  eclipse-mosquitto:2 \
  mosquitto_pub -L "wss://$USER_NAME:$PASSWORD@$HOST:$PORT/$TOPIC" --cafile /certs/ca.crt -m "$MESSAGE"

sleep 1

echo "[4/4] Verifying subscriber received the message..."
if docker logs "$SUB_NAME" 2>&1 | grep -q "$MESSAGE"; then
  echo "✅ SUCCESS: WSS publish/subscribe works with TLS + auth"
else
  echo "❌ FAILURE: Message not received over WSS"
  echo "   Check broker logs: docker logs -f mosquitto"
  exit 1
fi

echo "----------------------------------------------------------------"