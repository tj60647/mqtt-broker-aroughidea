#!/bin/bash
set -euo pipefail

USER_NAME="${MQTT_USER:-workshop-user}"
PASSWORD="${MQTT_PASS:-mqtt-fun-2026}"
HOST="${MQTT_HOST:-localhost}"
PORT="${MQTT_MQTTS_PORT:-8883}"
TOPIC="${MQTT_TOPIC:-test/healthcheck}"
MESSAGE="${MQTT_MESSAGE:-HELLO_MQTTS}"
CA_FILE="${MQTT_CA_FILE:-$PWD/config/certs/ca.crt}"
SUB_NAME="mqtt-mqtts-tester-sub"

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
echo "Testing MQTT over TLS (MQTTS) on $HOST:$PORT"
echo "----------------------------------------------------------------"

echo "[1/4] TLS handshake check with OpenSSL..."
if openssl s_client -connect "$HOST:$PORT" -servername "$HOST" -CAfile "$CA_FILE" < /dev/null > /tmp/mqtt-mqtts-openssl.log 2>&1; then
  echo "✅ TLS handshake succeeded"
else
  echo "❌ FAILURE: TLS handshake failed"
  echo "   Check certs/listener with: docker logs mosquitto"
  echo "   OpenSSL output:"
  tail -n 20 /tmp/mqtt-mqtts-openssl.log || true
  exit 1
fi

echo "[2/4] Starting authenticated MQTTS subscriber..."
docker run --name "$SUB_NAME" --rm -d --network host \
  -v "$CA_FILE:/certs/ca.crt:ro" \
  eclipse-mosquitto:2 \
  mosquitto_sub -h "$HOST" -p "$PORT" --cafile /certs/ca.crt -u "$USER_NAME" -P "$PASSWORD" -t "$TOPIC" -v > /dev/null

sleep 2

echo "[3/4] Publishing authenticated MQTTS message '$MESSAGE'..."
docker run --rm --network host \
  -v "$CA_FILE:/certs/ca.crt:ro" \
  eclipse-mosquitto:2 \
  mosquitto_pub -h "$HOST" -p "$PORT" --cafile /certs/ca.crt -u "$USER_NAME" -P "$PASSWORD" -t "$TOPIC" -m "$MESSAGE"

sleep 1

echo "[4/4] Verifying subscriber received the message..."
if docker logs "$SUB_NAME" 2>&1 | grep -q "$MESSAGE"; then
  echo "✅ SUCCESS: MQTTS publish/subscribe works with TLS + auth"
else
  echo "❌ FAILURE: Message not received over MQTTS"
  echo "   Check broker logs: docker logs -f mosquitto"
  exit 1
fi

echo "----------------------------------------------------------------"