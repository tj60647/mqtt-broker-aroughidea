#!/bin/bash
set -euo pipefail

# NOTE: These containers use --network host, which works on Linux only.
# On Docker Desktop (macOS/Windows), set MQTT_HOST=host.docker.internal
# or run openssl/mosquitto_pub/mosquitto_sub from the host directly.

USER_NAME="${MQTT_USER:-workshop-user}"
PASSWORD="${MQTT_PASS:-mqtt-fun-2026}"
HOST="${MQTT_HOST:-localhost}"
PORT="${MQTT_MQTTS_PORT:-8883}"
TOPIC="${MQTT_TOPIC:-test/healthcheck}"
MESSAGE="${MQTT_MESSAGE:-HELLO_MQTTS}"
READY_MESSAGE="READY_PROBE_${RANDOM}_$$"
CA_FILE="${MQTT_CA_FILE:-$PWD/config/certs/ca.crt}"
SUB_NAME="mqtt-mqtts-tester-sub"
SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"

# shellcheck source=scripts/smoke-test-lib.sh disable=SC1091
. "$SCRIPT_DIR/smoke-test-lib.sh"

cleanup() {
  cleanup_container "$SUB_NAME"
}

trap cleanup EXIT

publish_once() {
  local payload="$1"
  docker run --rm --network host \
    -v "$CA_FILE:/certs/ca.crt:ro" \
    eclipse-mosquitto:2 \
    mosquitto_pub -h "$HOST" -p "$PORT" --cafile /certs/ca.crt -u "$USER_NAME" -P "$PASSWORD" -t "$TOPIC" -m "$payload"
}

publish_readiness_probe() {
  publish_once "$READY_MESSAGE"
}

publish_test_message() {
  publish_once "$MESSAGE"
}

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
docker run --name "$SUB_NAME" -d --network host \
  -v "$CA_FILE:/certs/ca.crt:ro" \
  eclipse-mosquitto:2 \
  mosquitto_sub -d -h "$HOST" -p "$PORT" --cafile /certs/ca.crt -u "$USER_NAME" -P "$PASSWORD" -t "$TOPIC" -v > /dev/null

if ! wait_for_subscriber_ready "$SUB_NAME" "MQTTS"; then
  exit 1
fi

if ! publish_with_retry publish_readiness_probe; then
  echo "❌ FAILURE: MQTTS readiness probe publish failed."
  docker logs mosquitto 2>&1 | tail -n 50 || true
  exit 1
fi

if ! wait_for_subscriber_message "$SUB_NAME" "$READY_MESSAGE" "MQTTS"; then
  exit 1
fi

echo "[3/4] Publishing authenticated MQTTS message '$MESSAGE'..."
if ! publish_with_retry publish_test_message; then
  echo "❌ FAILURE: MQTTS publish failed after retries."
  echo "   Broker logs:"
  docker logs mosquitto 2>&1 | tail -n 50 || true
  exit 1
fi

sleep 1

echo "[4/4] Verifying subscriber received the message..."
if docker logs "$SUB_NAME" 2>&1 | grep -q "$MESSAGE"; then
  echo "✅ SUCCESS: MQTTS publish/subscribe works with TLS + auth"
else
  echo "❌ FAILURE: Message not received over MQTTS"
  echo "   Subscriber logs:"
  docker logs "$SUB_NAME" 2>&1 | tail -n 50 || true
  echo "   Check broker logs: docker logs -f mosquitto"
  exit 1
fi

echo "----------------------------------------------------------------"
