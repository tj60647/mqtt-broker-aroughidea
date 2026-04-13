<img src="mqtt-icon.svg" alt="MQTT icon" width="80" align="left" style="margin-right:12px"/>

# MQTT Workshop Broker

<br clear="left"/>

Welcome! This guide helps you set up a message broker for your workshop — or connect to one that's already running.

**MQTT** is a lightweight messaging protocol. Think of the broker as a post office: devices and browser apps send messages to it, and it forwards them to anyone who is listening. This repository sets up that post office on a cheap cloud server.

---

## 👋 Are you a workshop participant?

If an organizer has already set up the broker for you, head straight to the participant guide:

📄 **[CLIENT_SETUP.md](CLIENT_SETUP.md)** — how to connect your browser or p5.js sketch to the broker.

Your organizer should give you:
- The broker's **IP address** (e.g., `203.0.113.10`)
- A **username** and **password** (e.g., `workshop-user` / `mqtt-fun-2026`)
- The **`ca.crt` file** (needed for secure connections — see Step 11 below)

---

## 🛠️ Are you an organizer setting up the broker?

Follow the steps below. You will:
1. Rent a small cloud server (DigitalOcean Droplet — about $4–6/month).
2. Install Docker on it.
3. Clone this repo and run a few commands.
4. Share connection details with participants.

**What you need before you start:**
- A [DigitalOcean account](https://www.digitalocean.com/) (or another Linux VPS provider).
- A computer with a terminal (PowerShell on Windows, Terminal on Mac/Linux).
- About 30–45 minutes.

---

## Step 1: Create a Server (DigitalOcean Droplet)

A "Droplet" is DigitalOcean's name for a virtual server.

1. Log in to DigitalOcean and click **Create → Droplets**.
2. **Region:** Pick the one geographically closest to your participants (e.g., NYC1 or SFO2).
3. **Image:** Choose **Ubuntu 22.04 LTS x64**.
4. **Size:**
   - Droplet Type: **Basic**
   - CPU: **Regular (SSD)**
   - $4/mo (512 MB / 1 CPU) or $6/mo (1 GB / 1 CPU) is plenty for a workshop.
5. **Authentication — SSH Key** (more secure than a password):
   - If you don't have an SSH key yet:
     1. Open a terminal on your own computer.
     2. Run: `ssh-keygen -t ed25519 -C "mqtt-broker"`
        - Press **Enter** when asked for a file name (use the default).
        - Press **Enter** twice when asked for a passphrase (no passphrase is fine here).
     3. Print your public key:
        - **Windows (PowerShell):** `Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub`
        - **Mac/Linux:** `cat ~/.ssh/id_ed25519.pub`
     4. In DigitalOcean, click **New SSH Key**, paste the output, and name it `mqtt-broker`.
6. **Hostname:** Near the bottom of the page, change the default name to something simple like `mqtt-broker`. (This is just a label — it doesn't affect anything.)
7. **IPv6:** Leave it unchecked — not needed here.
8. Click **Create Droplet** and wait about 30 seconds for it to start.

---

## Step 2: Install Docker on the Server

1. **Find your server's IP address** in the DigitalOcean dashboard (listed under your new Droplet).
2. **Connect via SSH** from your own computer's terminal:
   ```sh
   ssh root@<YOUR_DROPLET_IP>
   ```
   The first time you connect, you'll see a message like:
   > *The authenticity of host '...' can't be established.*

   This is normal. Type `yes` and press Enter.

3. You should now see a prompt like `root@mqtt-broker:~#`. You're on the server. Run the following commands here.

   **Block A — Update and install Docker:**
   ```sh
   sudo apt update
   sudo apt install -y ca-certificates curl gnupg
   curl -fsSL https://get.docker.com | sudo sh
   sudo usermod -aG docker $USER
   newgrp docker
   ```

   **Block B — Install the Compose plugin:**
   ```sh
   sudo apt install -y docker-compose-plugin
   ```

   **Block C — Verify the installation:**
   ```sh
   docker --version
   docker compose version
   ```
   ✅ You should see version numbers for both (e.g., `Docker version 29.x.x` and `Docker Compose version v2.x.x`).

---

## Step 3: Download This Repository

Still inside your SSH session (on the server), run:
```sh
git clone https://github.com/tj60647/mqtt-broker-aroughidea.git
cd mqtt-broker-aroughidea
```

---

## Step 4: Create Storage Folders

The broker needs folders to save data and logs:
```sh
mkdir -p data log
```

---

## Step 5: Set Up Topic Permissions

The broker uses an **Access Control List (ACL)** — a simple text file that controls which users can send or receive messages on which topics.

Copy the example file to activate it:
```sh
cp config/acl.example config/acl
```

The default ACL gives `workshop-user` full access to all topics. You can edit `config/acl` later to add per-student restrictions if you need them.

The main configuration file (`config/mosquitto.conf`) is already included in the repo and ready to use — no edits needed for a standard workshop.

> **Production tip:** If all your clients will connect over TLS (port 8883), you can restrict the unencrypted listener to the server itself. Open `config/mosquitto.conf` and change `listener 1883` to `listener 1883 127.0.0.1`.

---

## Step 6: Create a User Account

The broker requires a username and password — anonymous connections are disabled for security. For a workshop, one shared account is usually fine.

Run this command to create a user named **`workshop-user`**:
```sh
docker run --rm -it \
  --user 1883:1883 \
  -v "$PWD/config:/mosquitto/config" \
  eclipse-mosquitto:2 \
  sh -lc 'mosquitto_passwd -c /mosquitto/config/passwords workshop-user'
```
You'll be prompted to type a password twice. Choose something memorable for the workshop (e.g., `mqtt-fun-2026`).

> ⚠️ **Don't use a weak default password on a public server.** Anyone who finds the broker's IP address could connect. Pick something that isn't trivially guessable.

To add a second user later (without overwriting the first), drop the `-c` flag:
```sh
docker run --rm -it \
  --user 1883:1883 \
  -v "$PWD/config:/mosquitto/config" \
  eclipse-mosquitto:2 \
  sh -lc 'mosquitto_passwd /mosquitto/config/passwords anotheruser'
```

---

## Step 7: Generate Security Certificates

Certificates are what allow devices to talk to the broker **securely** (encrypted, so no one can eavesdrop). We generate a self-signed set specifically for this workshop.

Run the included script:
```sh
chmod +x scripts/generate-certs.sh
./scripts/generate-certs.sh
```

This creates three files inside `config/certs/`:

| File | What it is |
|------|-----------|
| `ca.crt` | The "trust anchor" — distribute this to participants |
| `server.crt` | The broker's identity certificate |
| `server.key` | The broker's private key — keep this secret |

> **About `ca.key`:** This file is also generated and kept in `config/certs/`. It is excluded from git. Guard it — anyone with this file could impersonate your broker. For a short workshop this is fine; for long-running production use, store it somewhere safer.

If you ever regenerate certificates, restart the broker afterwards:
```sh
docker compose restart mosquitto
```

---

## Step 8: Start the Broker

```sh
docker compose up -d
```

Check that it started:
```sh
docker ps
docker logs mosquitto
```

You should see the broker's startup messages and no errors.

---

## Step 9: Open the Firewall

Ubuntu includes a firewall (`ufw`) that blocks all ports by default. Open the ports the broker uses:

```sh
sudo ufw allow ssh
sudo ufw allow 1883/tcp comment 'MQTT plaintext'
sudo ufw allow 8883/tcp comment 'MQTT TLS'
sudo ufw allow 9001/tcp comment 'MQTT Secure WebSockets'
sudo ufw enable
```

Verify:
```sh
sudo ufw status
```

---

## Step 10: Verify Everything Works

Run the built-in test scripts to confirm the broker is accepting connections.

**Test plain MQTT (port 1883):**
```sh
chmod +x scripts/test-connection.sh
./scripts/test-connection.sh
```

**Test MQTT over TLS (port 8883):**
```sh
chmod +x scripts/test-mqtts.sh
./scripts/test-mqtts.sh
```

**Test secure WebSockets (port 9001 — used by browser clients):**
```sh
chmod +x scripts/test-wss.sh
./scripts/test-wss.sh
```

✅ Each script prints `SUCCESS: Message received!` if everything is working.

> **Note:** These test scripts use `--network host` inside Docker, which only works on Linux. If you're running them from macOS or Windows (Docker Desktop), run `export MQTT_HOST=host.docker.internal` first, or use a locally installed MQTT client instead.

---

## Step 11: Share Connection Details with Participants

Give participants the following information (a quick message or printed card works well):

| Setting | Value |
|---------|-------|
| Broker IP | `<YOUR_DROPLET_IP>` |
| Secure port | `8883` (MQTT over TLS) |
| WebSocket port | `9001` (for browser/p5.js clients) |
| Username | `workshop-user` |
| Password | *(the password you chose in Step 6)* |
| CA Certificate | `config/certs/ca.crt` *(see below)* |

### Distributing the CA Certificate

Participants need the `ca.crt` file so their computer trusts the broker. To get it off the server, run this **on your own computer** (not the server):

```sh
scp root@<YOUR_DROPLET_IP>:~/mqtt-broker-aroughidea/config/certs/ca.crt .
```

You can then share the file via email, Slack, a shared folder, or a USB drive.

### Participant connection settings (MQTT Explorer or similar tool)

| Field | Value |
|-------|-------|
| Protocol | `mqtts` |
| Host | `<YOUR_DROPLET_IP>` |
| Port | `8883` |
| Username | `workshop-user` |
| Password | *(your password)* |
| CA Certificate | Select the `ca.crt` file |
| Client Certificate | *(leave blank)* |
| Client Key | *(leave blank)* |

If a client gets a "hostname mismatch" error, regenerate certs with the server's actual IP address:
```sh
CERT_CN=<your_droplet_ip> CERT_SAN_IP_1=<your_droplet_ip> ./scripts/generate-certs.sh
docker compose restart mosquitto
```
Then redistribute the new `ca.crt`.

### Browser and p5.js clients (WebSockets)

Browser clients connect using:
- **URL:** `wss://<YOUR_DROPLET_IP>:9001`
- **Username/Password:** same as above.

Browsers are stricter about certificate trust. See [CLIENT_SETUP.md](CLIENT_SETUP.md) for full p5.js integration instructions. For production use with real browser clients, use a domain name with a CA-signed certificate (e.g., Let's Encrypt) instead of a self-signed one.

---

## Troubleshooting

**"Connection refused" error**
- Is the container running? → `docker ps`
- Are firewall ports open? → `sudo ufw status`

**"Certificate error" or "hostname mismatch"**
- The self-signed cert defaults to `localhost`. If clients connect by IP, regenerate certs with the IP address as the CN/SAN (see Step 11 above).
- Browser WSS connections are stricter than desktop tools.

**"Invalid password" or "not authorized"**
- Check broker logs: `docker logs -f mosquitto`
- Make sure the username in `config/acl` matches the one you created in Step 6.

**Tests fail on macOS/Windows**
- The test scripts need `MQTT_HOST=host.docker.internal`. Set that environment variable before running.

**Windows: Trusting the CA for `wss://localhost:9001`**

Run PowerShell as Administrator in the repo folder:
```powershell
certutil -addstore -f Root .\config\certs\ca.crt
```
Then close and reopen your browser completely.

---

## Moving or Resetting the Broker

To move the broker to a new server:
1. Copy the repository folder.
2. Copy `data/` too, if you want to keep stored messages.
3. Regenerate certificates (the new server will have a different IP).
4. Recreate passwords if you want a fresh start.

To reset for a new workshop: delete `config/passwords`, `config/certs/`, and `data/`, then repeat Steps 6–8.

---

## Security Notes

- **Passwords** (`config/passwords`) and **certificates** (`config/certs/`) are excluded from git — they are generated at runtime.
- **Never commit these files** to the repository.
- If a password or certificate may have been exposed, regenerate it immediately and restart the broker.
- For a long-running production deployment, use a domain name with a CA-signed certificate (e.g., Let's Encrypt) instead of self-signed ones.
