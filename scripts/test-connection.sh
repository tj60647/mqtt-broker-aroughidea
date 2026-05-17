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
SUB_NAME="mqtt-tester-sub"

cleanup() {
  docker stop "$SUB_NAME" > /dev/null 2>&1 || true
}

trap cleanup EXIT

echo "----------------------------------------------------------------"
echo "Testing MQTT Connection (Port $PORT)..."
echo "----------------------------------------------------------------"

# 1. Start a Subscriber in the background
# We name it 'mqtt-tester-sub' so we can find it and kill it later.
echo "[1/3] Starting background subscriber..."
docker run --name "$SUB_NAME" --rm -d --network host \
  eclipse-mosquitto:2 \
  mosquitto_sub -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "test/healthcheck" -v > /dev/null

# Give it a moment to connect
sleep 2

# 2. Publish a message
echo "[2/3] Publishing test message 'HELLO_WORLD'..."
docker run --rm --network host \
  eclipse-mosquitto:2 \
  mosquitto_pub -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "test/healthcheck" -m "HELLO_WORLD"

# 3. Check if the subscriber received it
# We check the logs of the background container
echo "[3/3] Verify delivery..."
if docker logs "$SUB_NAME" 2>&1 | grep -q "HELLO_WORLD"; then
  echo "✅ SUCCESS: Message received!"
else
  echo "❌ FAILURE: Message not received."
  echo "   Check 'docker logs mosquitto' for broker errors."
  exit 1
fi

echo "----------------------------------------------------------------"
