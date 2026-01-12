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
   - *Need a key?*:
     1. Open a terminal (PowerShell on Windows, Terminal on Mac/Linux).
     2. Run: `ssh-keygen -t ed25519 -C "mqtt-broker"`
        - **Important:** When prompted for a file, just press **Enter** (defaults).
        - **Passphrase:** Press **Enter** twice for no passphrase (easiest for automation/testing).
     3. **Copy the Public Key:**
        - **Windows (PowerShell):** `Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub`
        - **Mac/Linux:** `cat ~/.ssh/id_ed25519.pub`
     4. **Add to DigitalOcean:**
        - Click "Add SSH Key" in DigitalOcean and paste the output.
        - Name it "mqtt-broker".
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
log_dest stdout

# Global Authentication (applies to all listeners)
per_listener_settings false
allow_anonymous false
password_file /mosquitto/config/passwords
acl_file /mosquitto/config/acl

# Standard MQTT (1883)
listener 1883

# MQTT over TLS (8883)
listener 8883
certfile /mosquitto/config/certs/server.crt
keyfile /mosquitto/config/certs/server.key
cafile /mosquitto/config/certs/ca.crt
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
- It creates the folder `config/certs/` if it doesn't exist.
- It generates the files (`ca.crt`, `server.crt`, `server.key`) and places them inside that folder.



## Step 8: Start the Broker
```sh
docker compose up -d
```

Verify:
```sh
docker ps
docker logs mosquitto
```

### Verify Connectivity
You can run the included test script to confirm the broker is accepting messages (uses port 1883):
```sh
chmod +x scripts/test-connection.sh
./scripts/test-connection.sh
```

## Step 9: Configure Firewall (UFW)
Ubuntu comes with a firewall called `ufw`. It is likely creating a "deny all" rule by default, so we need to open the MQTT ports.

Run these commands on the droplet:
```sh
sudo ufw allow 1883/tcp comment 'MQTT plaintext'
sudo ufw allow 8883/tcp comment 'MQTT TLS'
sudo ufw allow 9001/tcp comment 'MQTT Websockets'
# Ensure SSH is still allowed (it usually is, but good to be safe)
sudo ufw allow ssh
sudo ufw enable
```

## Step 10: Secure Client Connection (The "Loose End")
To connect securely from your **local computer** (e.g., using MQTT Explorer), you need the **Certificate Authority (CA)** file we generated in Step 7. Without it, your computer won't trust the broker.

### 1. Download the CA Certificate
Run this command **on your local computer** (not the droplet):

```sh
# Replace with your actual droplet IP
scp root@<YOUR_DROPLET_IP>:~/mqtt-broker-aroughidea/config/certs/ca.crt .
```
*This downloads `ca.crt` to your current folder.*

### 2. Configure MQTT Explorer (or other clients)
- **Host:** `<YOUR_DROPLET_IP>`
- **Port:** `8883`
- **Protocol:** `mqtts` (TLS)
- **Username/Password:** `workshop-user` / `mqtt-fun-2026` (or whatever you set)
- **TLS/certificates:**
  - **CA Certificate:** Select the `ca.crt` file you just downloaded.
  - **Client Certificate:** Leave blank.
  - **Client Key:** Leave blank.
  - **Uncheck** "Validate certificate" if you are having hostname issues, but providing the CA is usually enough.

## Migration / Reuse
To move this broker to another host:
1. Copy the repository
2. Copy `data/` if persistence matters
3. Regenerate certificates if hostname/IP changes
4. Recreate passwords if desired

## Troubleshooting
- **Connection Refused?** Check if the container is running (`docker ps`) and if Firewall ports are open (`sudo ufw status`).
- **Certificate Errors?** If your client complains about "Hostname mismatch" (because we used a simple self-signed cert), try disabling "Validate Server Certificate" in your client settings, OR regenerate the certs with the specific IP address in `scripts/generate-certs.sh`.
- **Logs:** Run `docker logs -f mosquitto` to see why connections are being rejected (e.g., "invalid password").

## Final Guidance
This repository should remain:
- small
- explicit
- boring
- safe

If it starts to feel like an “app,” it has grown too far.
