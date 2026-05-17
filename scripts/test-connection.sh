#!/bin/bash
set -euo pipefail
# A simple script to verify the broker is accepting connections.
# It uses the Docker image to act as a client, so you don't need to install tools.
#
# NOTE: These containers use --network host, which works on Linux only.
# On Docker Desktop (macOS/Windows), use MQTT_HOST=host.docker.internal
# or connect from the host directly using an installed mosquitto client.

USER="${MQTT_USER:-workshop-user}"
PASS="${MQTT_PASS:-mqtt-fun-2026}"
HOST="${MQTT_HOST:-localhost}"
PORT="${MQTT_PORT:-1883}"
TOPIC="${MQTT_TOPIC:-test/healthcheck}"
MESSAGE="${MQTT_MESSAGE:-HELLO_WORLD}"
READY_MESSAGE="READY_PROBE_${RANDOM}_$$"
SUB_NAME="mqtt-tester-sub"
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
    eclipse-mosquitto:2 \
    mosquitto_pub -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "$TOPIC" -m "$payload"
}

publish_readiness_probe() {
  publish_once "$READY_MESSAGE"
}

publish_test_message() {
  publish_once "$MESSAGE"
}

echo "----------------------------------------------------------------"
echo "Testing MQTT Connection (Port $PORT)..."
echo "----------------------------------------------------------------"

# 1. Start a Subscriber in the background
# We name it 'mqtt-tester-sub' so we can find it and kill it later.
echo "[1/3] Starting background subscriber..."
docker run --name "$SUB_NAME" -d --network host \
  eclipse-mosquitto:2 \
  mosquitto_sub -d -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "$TOPIC" -v > /dev/null

if ! wait_for_subscriber_ready "$SUB_NAME" "MQTT"; then
  exit 1
fi

if ! publish_with_retry publish_readiness_probe; then
  echo "❌ FAILURE: Readiness probe publish failed."
  docker logs mosquitto 2>&1 | tail -n 50 || true
  exit 1
fi

if ! wait_for_subscriber_message "$SUB_NAME" "$READY_MESSAGE" "MQTT"; then
  exit 1
fi

# 2. Publish a message
echo "[2/3] Publishing test message '$MESSAGE'..."
if ! publish_with_retry publish_test_message; then
  echo "❌ FAILURE: Publish failed after retries."
  echo "   Broker logs:"
  docker logs mosquitto 2>&1 | tail -n 50 || true
  exit 1
fi

# 3. Check if the subscriber received it
# We check the logs of the background container
echo "[3/3] Verify delivery..."
if docker logs "$SUB_NAME" 2>&1 | grep -q "$MESSAGE"; then
  echo "✅ SUCCESS: Message received!"
else
  echo "❌ FAILURE: Message not received."
  echo "   Subscriber logs:"
  docker logs "$SUB_NAME" 2>&1 | tail -n 50 || true
  echo "   Check 'docker logs mosquitto' for broker errors."
  exit 1
fi

echo "----------------------------------------------------------------"
