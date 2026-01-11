# Implementation Guide (DigitalOcean + Mosquitto)

## Overview
This repository defines a portable MQTT broker using Eclipse Mosquitto, intended for:
- prototyping experiments
- small workshops
- temporary or resettable deployments

It is single-node, non-HA, and intentionally simple.

## Deployment Target
- **Provider:** DigitalOcean
- **OS:** Ubuntu LTS (22.04 or later)
- **Runtime:** Docker + Docker Compose
- **Broker:** Eclipse Mosquitto 2.x

## Step 1: Create a Droplet
1. Create a new DigitalOcean Droplet
2. Choose Ubuntu LTS
3. Enable SSH access
4. Select a basic size (1 vCPU / 1 GB RAM is sufficient)
5. Assign a static hostname or DNS name if desired

## Step 2: Install Docker on the Droplet
SSH into the droplet, then:

```sh
sudo apt update
sudo apt install -y ca-certificates curl gnupg
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
newgrp docker
```

Install Docker Compose plugin:
```sh
sudo apt install -y docker-compose-plugin
```

Verify:
```sh
docker --version
docker compose version
```

## Step 3: Clone the Repository
```sh
git clone https://github.com/<your-org>/mqtt-broker-aroughidea.git
cd mqtt-broker-aroughidea
```

## Step 4: Create Runtime Directories
```sh
mkdir -p data log
```

## Step 5: Configure Mosquitto
Copy and edit ACLs:
```sh
cp config/acl.example config/acl
```

Create `config/mosquitto.conf` (Copilot can generate this from the instructions).
Ensure it references:
- `password_file /mosquitto/config/passwords`
- `acl_file /mosquitto/config/acl`
- TLS cert paths under `/mosquitto/config/certs`

## Step 6: Create User Passwords
Use the official Mosquitto image to generate password hashes:
```sh
docker run --rm -it \
  -v "$PWD/config:/mosquitto/config" \
  eclipse-mosquitto:2 \
  sh -lc 'mosquitto_passwd -c /mosquitto/config/passwords alice'
```
Repeat for each user.

## Step 7: Generate TLS Certificates
Generate a private CA and server certificate per deployment.
You may:
- use your own OpenSSL workflow
- or implement `scripts/generate-certs.sh`

Certificates must be placed in:
```
config/certs/
  ca.crt
  server.crt
  server.key
```
These files must never be committed.

## Step 8: Start the Broker
```sh
docker compose up -d
```

Verify:
```sh
docker ps
docker logs mosquitto
```

## Step 9: Open Firewall Ports
On the droplet firewall, allow:
- `1883` (optional, non-TLS)
- `8883` (TLS MQTT)
- `9001` / `9443` (if using WebSockets)

## Migration / Reuse
To move this broker to another host:
1. Copy the repository
2. Copy `data/` if persistence matters
3. Regenerate certificates if hostname/IP changes
4. Recreate passwords if desired

## Final Guidance
This repository should remain:
- small
- explicit
- boring
- safe

If it starts to feel like an “app,” it has grown too far.
