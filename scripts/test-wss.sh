#!/bin/bash
set -euo pipefail

# WSS smoke test for deployment validation.
# Validates:
# 1) TLS handshake on WebSocket listener
# 2) Authenticated subscribe/publish over wss://
#
# NOTE: These containers use --network host, which works on Linux only.
# On Docker Desktop (macOS/Windows), set MQTT_HOST=host.docker.internal
# or run mosquitto_pub/mosquitto_sub from the host directly.

USER_NAME="${MQTT_USER:-workshop-user}"
PASSWORD="${MQTT_PASS:-mqtt-fun-2026}"
HOST="${MQTT_HOST:-localhost}"
PORT="${MQTT_WSS_PORT:-9001}"
TOPIC="${MQTT_TOPIC:-test/healthcheck}"
MESSAGE="${MQTT_MESSAGE:-HELLO_WSS}"
READY_MESSAGE="READY_PROBE_${RANDOM}_$$"
CA_FILE="${MQTT_CA_FILE:-$PWD/config/certs/ca.crt}"
SUB_NAME="mqtt-wss-tester-sub"
SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"

# shellcheck source=scripts/smoke-test-lib.sh disable=SC1091
. "$SCRIPT_DIR/smoke-test-lib.sh"

cleanup() {
  cleanup_container "$SUB_NAME"
}

trap cleanup EXIT

wss_validate_input() {
  local value="$1"
  local label="$2"
  local pattern="$3"

  if printf '%s' "$value" | grep -Eq "$pattern"; then
    echo "❌ FAILURE: $label contains URL-reserved characters not supported by the WSS smoke test URL format."
    echo "   $label value: $value"
    exit 1
  fi
}

publish_once() {
  local payload="$1"
  docker run --rm --network host \
    -v "$CA_FILE:/certs/ca.crt:ro" \
    eclipse-mosquitto:2 \
    mosquitto_pub -L "wss://$USER_NAME:$PASSWORD@$HOST:$PORT/$TOPIC" --cafile /certs/ca.crt -m "$payload"
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
wss_validate_input "$USER_NAME" "MQTT_USER" '[@:/?#%]'
wss_validate_input "$PASSWORD" "MQTT_PASS" '[@:/?#%]'
wss_validate_input "$TOPIC" "MQTT_TOPIC" '[?#%+]'

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
docker run --name "$SUB_NAME" -d --network host \
  -v "$CA_FILE:/certs/ca.crt:ro" \
  eclipse-mosquitto:2 \
  mosquitto_sub -d -L "wss://$USER_NAME:$PASSWORD@$HOST:$PORT/$TOPIC" --cafile /certs/ca.crt -v > /dev/null

if ! wait_for_subscriber_ready "$SUB_NAME" "WSS"; then
  exit 1
fi

if ! publish_with_retry publish_readiness_probe; then
  echo "❌ FAILURE: WSS readiness probe publish failed."
  docker logs mosquitto 2>&1 | tail -n 50 || true
  exit 1
fi

if ! wait_for_subscriber_message "$SUB_NAME" "$READY_MESSAGE" "WSS"; then
  exit 1
fi

echo "[3/4] Publishing authenticated WSS message '$MESSAGE'..."
if ! publish_with_retry publish_test_message; then
  echo "❌ FAILURE: WSS publish failed after retries."
  echo "   Broker logs:"
  docker logs mosquitto 2>&1 | tail -n 50 || true
  exit 1
fi

sleep 1

echo "[4/4] Verifying subscriber received the message..."
if docker logs "$SUB_NAME" 2>&1 | grep -q "$MESSAGE"; then
  echo "✅ SUCCESS: WSS publish/subscribe works with TLS + auth"
else
  echo "❌ FAILURE: Message not received over WSS"
  echo "   Subscriber logs:"
  docker logs "$SUB_NAME" 2>&1 | tail -n 50 || true
  echo "   Check broker logs: docker logs -f mosquitto"
  exit 1
fi

echo "----------------------------------------------------------------"
