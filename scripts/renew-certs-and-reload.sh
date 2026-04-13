#!/bin/sh
set -eu

# Renew Let's Encrypt certificates and reload Mosquitto if renewal succeeds.
# Intended to run on the DigitalOcean droplet.
#
# PREREQUISITE: The docker-compose.yml must mount the Let's Encrypt directory
# into the container (e.g. /etc/letsencrypt:/etc/letsencrypt:ro) and
# mosquitto.conf must reference those cert paths. See TRUSTED_CERTS_ROADMAP.md.

BROKER_CONTAINER="${BROKER_CONTAINER:-mosquitto}"
RELOAD_MODE="${RELOAD_MODE:-hup}"

if ! command -v certbot >/dev/null 2>&1; then
  echo "❌ certbot not found. Install certbot first."
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "❌ docker not found. Install Docker first."
  exit 1
fi

echo "[1/2] Running certificate renewal..."
certbot renew --quiet

echo "[2/2] Reloading broker TLS configuration..."
if [ "$RELOAD_MODE" = "restart" ]; then
  docker compose restart "$BROKER_CONTAINER"
else
  docker kill -s HUP "$BROKER_CONTAINER"
fi

echo "✅ Renewal flow complete."