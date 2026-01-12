#!/bin/bash
# A simple script to verify the broker is accepting connections.
# It uses the Docker image to act as a client, so you don't need to install tools.

USER="workshop-user"
PASS="mqtt-fun-2026"
HOST="localhost"
PORT="1883"

echo "----------------------------------------------------------------"
echo "Testing MQTT Connection (Port $PORT)..."
echo "----------------------------------------------------------------"

# 1. Start a Subscriber in the background
# We name it 'mqtt-tester-sub' so we can find it and kill it later.
echo "[1/3] Starting background subscriber..."
docker run --name mqtt-tester-sub --rm -d --network host \
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
if docker logs mqtt-tester-sub 2>&1 | grep -q "HELLO_WORLD"; then
  echo "✅ SUCCESS: Message received!"
else
  echo "❌ FAILURE: Message not received."
  echo "   Check 'docker logs mosquitto' for broker errors."
fi

# Cleanup
docker stop mqtt-tester-sub > /dev/null
echo "----------------------------------------------------------------"
