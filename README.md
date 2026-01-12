# Implementation Guide (DigitalOcean + Mosquitto)

## Overview
This repository defines a portable MQTT broker using Eclipse Mosquitto, intended for:
- prototyping experiments
- small workshops
- temporary or resettable deployments

It is single-node, non-high availability, and intentionally simple.

### Architecture Definitions
- **Single Node:** All components (broker, storage, networking) run on one virtual machine. There is no horizontal scaling.
- **Single Point of Failure:** The broker runs on one node (server/container). If that node crashes or the server goes down, the entire MQTT service stops.
- **No Redundancy:** There are no backup servers or clusters waiting to take over automatically.
- **Simpler Architecture:** It avoids the complexity of distributed state, clustering protocols, and load balancers, favoring a simpler "easy to destroy and recreate" approach.

## Deployment Target
- **Provider:** DigitalOcean
- **OS:** Ubuntu LTS (22.04 or later)
- **Runtime:** Docker + Docker Compose
- **Broker:** Eclipse Mosquitto 2.x

## Step 1: Create a Droplet
1. Create a new DigitalOcean Droplet
2. Choose Region: Choose the one closest to you (e.g. NYC1, SFO2)
3. Choose Image: **Ubuntu 22.04 LTS x64**
4. Choose Size:
   - **Droplet Type:** Basic
   - **CPU Options:** Regular (SSD)
   - **Price:** $4/mo (512 MB / 1 CPU) or $6/mo (1 GB / 1 CPU) is plenty.
5. **Authentication Method:** Choose **SSH Key**.
   - *Need a key? (Windows)*:
     1. Open PowerShell and run: `ssh-keygen -t ed25519 -C "mqtt-broker"`
        - **Important:** When prompted for a file, just press **Enter** (defaults).
        - **Passphrase:** Press **Enter** twice for no passphrase (easiest for automation/testing).
        - `-t ed25519`: Creates a more secure, modern, and shorter key type than RSA.
        - `-C "..."`: Adds a label so you can identify this key in the DigitalOcean dashboard.
     2. Copy the public key: `Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub`
        - The output will start with `ssh-ed25519` and end with `mqtt-broker`.
     3. Click "Add SSH Key" in DigitalOcean and paste the output.
        - **Name:** You can name it "mqtt-broker" (or your computer name) to keep track of it.
6. **Finalize Details:**
   - **Hostname:** Change the long default name (e.g., `ubuntu-s-1vcpu...`) to something simple like `mqtt-broker`.
     - *Note:* Look for a field labeled **Hostname** at the very bottom. By default, it will say something like `ubuntu-s-1vcpu-1gb-nyc1-01`. You can type `mqtt-broker` to make it easier to read in your dashboard. If you don't change it, the default name works fine too! It's just a label.
   - **IPv6:** Uncheck if enabled (not required for this broker).
   - Click **Create Droplet**.

## Step 2: Install Docker on the Droplet
1. **Find your IP Address:** Go to the DigitalOcean dashboard and copy the "ipv4" address of your new droplet (e.g., `203.0.113.10`).
2. **Connect via SSH:**
   - Open PowerShell on your computer.
   - Run: `ssh root@<your_droplet_ip>` (Replace `<your_droplet_ip>` with the actual address).
   - **First Time Warning:** You will see a message: *The authenticity of host... can't be established.*
     - This is normal for a new server. Type `yes` and press Enter to continue.
3. **Run Installation Commands:**
   Once you are logged in (you will see a prompt like `root@mqtt-broker:~#`), run these commands inside that SSH session.
   
   **Block A: Update and Install Docker**
   *(Paste this entire block first)*
   ```sh
   sudo apt update
   sudo apt install -y ca-certificates curl gnupg
   curl -fsSL https://get.docker.com | sudo sh
   sudo usermod -aG docker $USER
   newgrp docker
   ```

   **Block B: Install Compose Plugin**
   *(Run this next)*
   ```sh
   sudo apt install -y docker-compose-plugin
   ```

   **Block C: Verify Installation**
   *(Run this last to check if it worked)*
   ```sh
   docker --version
   docker compose version
   ```
   **Expected Output:**
   You should see version numbers for both commands (e.g., `Docker version 29.x.x` and `Docker Compose version v2.x.x`).

## Step 3: Clone the Repository
Run this inside your SSH session (on the droplet):
```sh
git clone https://github.com/tj60647/mqtt-broker-aroughidea.git
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

Create `config/mosquitto.conf` by running this command:

```sh
cat <<EOF > config/mosquitto.conf
persistence true
persistence_location /mosquitto/data/
log_dest file /mosquitto/log/mosquitto.log

# Standard MQTT (1883)
listener 1883
allow_anonymous false
password_file /mosquitto/config/passwords
acl_file /mosquitto/config/acl

# MQTT over TLS (8883)
listener 8883
certfile /mosquitto/config/certs/server.crt
keyfile /mosquitto/config/certs/server.key
cafile /mosquitto/config/certs/ca.crt
allow_anonymous false
password_file /mosquitto/config/passwords
acl_file /mosquitto/config/acl
EOF
```

## Step 6: Create User Passwords
Use the official Mosquitto image to generate password hashes.
*(Note: You can use a single shared username/password for everyone in a workshop)*

Run this command to create a user named **`workshop-user`**:
```sh
docker run --rm -it \
  -v "$PWD/config:/mosquitto/config" \
  eclipse-mosquitto:2 \
  sh -lc 'mosquitto_passwd -c /mosquitto/config/passwords workshop-user'
```
You will be prompted to type a password (e.g., `mqtt-fun-2026`).
You can repeat this command (without the `-c` flag) to add more distinct users if needed.

## Step 7: Generate TLS Certificates
We need to create a "Certificate Authority" (CA) and a server certificate so that devices can talk to the broker securely over port 8883.

Run this script (included in the repo) to generate them automatically:

```sh
chmod +x scripts/generate-certs.sh
./scripts/generate-certs.sh
```

**What this does:**
- Creates `config/certs/ca.crt` (The public certificate authority).
- Creates `config/certs/server.crt` & `server.key` (The server's credentials).


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
