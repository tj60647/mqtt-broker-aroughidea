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
- The broker's **address** (e.g., `mqtt.example.com` or `203.0.113.10`)
- A **username** and **password** (e.g., `workshop-user` / `mqtt-fun-2026`)

> If your organizer also gives you a **`ca.crt` file**, follow the certificate install step in CLIENT_SETUP.md before connecting.

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
- A domain name you control, with an **A record** pointing to your droplet's IP (e.g., `mqtt.example.com`). Free registrars like [Freenom](https://www.freenom.com) work; DigitalOcean can also manage DNS.
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

> **Why clone this repo?**
>
> The `eclipse-mosquitto:2` Docker image provides only the broker binary — it starts up with no authentication, no TLS, and no topic restrictions. On its own it is not safe to expose to the internet. This repository is the *configuration layer* that makes it workshop-ready:
>
> | File / folder | What it provides |
> |---|---|
> | `docker-compose.yml` | Wires the container, port mappings, and volume mounts together |
> | `config/mosquitto.conf` | Pre-configured listeners (1883, 8883, 9001), TLS paths, auth required |
> | `config/acl.example` | Topic permission template — copy once and edit |
> | `scripts/generate-certs.sh` | Generates a local CA + server cert so TLS works out of the box |
> | `scripts/test-*.sh` | Smoke tests to confirm each listener is working |
>
> Without cloning, you would need to create every one of these files by hand on the server before the container does anything useful.
>
> **Why not build a custom Docker image?**
> We use `eclipse-mosquitto:2` directly (no custom `Dockerfile`). All configuration is mounted into the container as read-only volumes at runtime. This means:
> - Secrets (passwords, certificates) never get baked into a Docker image layer.
> - You can change `mosquitto.conf` or `config/acl` and reload the broker with a single `SIGHUP` — no image rebuild, no redeploy.
> - The setup is auditable: every config decision is a plain text file you can read and version in git.

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

## Step 7: Get a TLS Certificate

Certificates let devices and browsers connect to the broker **securely** (encrypted). The recommended approach is a free, publicly trusted certificate from **Let's Encrypt** — participants never need to install a CA file because their devices already trust it.

**Prerequisites:**
- A domain name with an **A record** pointing to your droplet's IP (e.g., `mqtt.example.com`).
- DNS has propagated: `dig mqtt.your-domain.com` returns your droplet IP.

Choose one option:

---

### Option A — HTTP-01 (simplest; briefly uses port 80)

```sh
sudo apt install -y certbot
sudo certbot certonly --standalone \
  --non-interactive --agree-tos \
  -m your-email@example.com \
  -d mqtt.your-domain.com
```

> Certbot temporarily listens on port 80 to prove domain ownership, then exits. If your firewall blocks port 80, use Option B instead.

---

### Option B — DNS-01 via DigitalOcean API (no port 80; supports wildcards)

This option proves domain ownership through the DigitalOcean DNS API — port 80 is never touched.

1. In the DigitalOcean control panel, go to **API → Tokens → Generate New Token**.
   - Name it `certbot-dns`.
   - Grant it **write** access to **domains** only.
   - Copy the token — you will not see it again.

2. Save the token to the droplet:
   ```sh
   sudo mkdir -p /etc/letsencrypt
   sudo sh -c 'cat > /etc/letsencrypt/digitalocean.ini <<EOF
dns_digitalocean_token = YOUR_TOKEN_HERE
EOF'
   sudo chmod 600 /etc/letsencrypt/digitalocean.ini
   ```

3. Install certbot and the DigitalOcean DNS plugin:
   ```sh
   sudo apt install -y certbot python3-certbot-dns-digitalocean
   ```

4. Request the certificate:
   ```sh
   sudo certbot certonly \
     --dns-digitalocean \
     --dns-digitalocean-credentials /etc/letsencrypt/digitalocean.ini \
     --non-interactive --agree-tos \
     -m your-email@example.com \
     -d mqtt.your-domain.com
   ```

---

After either option, your certificate files are at:

| File | Path |
|------|------|
| Certificate + chain | `/etc/letsencrypt/live/mqtt.your-domain.com/fullchain.pem` |
| Private key | `/etc/letsencrypt/live/mqtt.your-domain.com/privkey.pem` |

### Wire the Certificate into Mosquitto

**1. Mount Let's Encrypt into the container.** Open `docker-compose.yml` and add this line to the `volumes:` list under the `mosquitto` service (indent to match the existing entries):

```yaml
      - /etc/letsencrypt:/etc/letsencrypt:ro
```

**2. Update `config/mosquitto.conf`** so both TLS listeners point to your Let's Encrypt files. Replace the `cafile`, `certfile`, and `keyfile` lines in both the `8883` and `9001` listener blocks with:

```
certfile /etc/letsencrypt/live/mqtt.your-domain.com/fullchain.pem
keyfile  /etc/letsencrypt/live/mqtt.your-domain.com/privkey.pem
```

Remove the `cafile` lines — they are not needed when using a public CA.

**3. Restart the broker** (required after config changes):

```sh
docker compose up -d
```

---

> **Not using a domain?** You can use a self-signed certificate instead:
> ```sh
> chmod +x scripts/generate-certs.sh
> ./scripts/generate-certs.sh
> ```
> Skip the `docker-compose.yml` and `mosquitto.conf` edits above — the config already points to the self-signed cert paths. Note: participants will need to install the `config/certs/ca.crt` file before their browser trusts the connection (see Step 11).

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

> **Using HTTP-01 cert issuance (Option A in Step 7)?** Also allow port 80 while certbot runs:
> ```sh
> sudo ufw allow 80/tcp comment 'ACME HTTP-01 challenge'
> ```
> You can remove it afterwards: `sudo ufw delete allow 80/tcp`

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

Give participants the following (a quick message or printed card works well):

| Setting | Value |
|---------|-------|
| Broker address | `mqtt.your-domain.com` |
| Secure port | `8883` (MQTT over TLS) |
| WebSocket port | `9001` (for browser/p5.js clients) |
| Username | `workshop-user` |
| Password | *(the password you chose in Step 6)* |

With a Let's Encrypt certificate, participants connect using the domain name — no CA certificate file to distribute.

### Participant connection settings (MQTT Explorer or similar tool)

| Field | Value |
|-------|-------|
| Protocol | `mqtts` |
| Host | `mqtt.your-domain.com` |
| Port | `8883` |
| Username | `workshop-user` |
| Password | *(your password)* |
| CA Certificate | *(leave blank — trusted automatically)* |
| Client Certificate | *(leave blank)* |
| Client Key | *(leave blank)* |

### Browser and p5.js clients (WebSockets)

Browser clients connect using:
- **URL:** `wss://mqtt.your-domain.com:9001`
- **Username/Password:** same as above.

Browsers trust Let's Encrypt certificates automatically — no cert file to install.

### ✅ You're done — share these details with participants

Send participants the broker address, username, and password, then point them to:

📄 **[CLIENT_SETUP.md](CLIENT_SETUP.md)** — step-by-step instructions for connecting a p5.js sketch to the broker.

---

> **Using self-signed certificates?** Participants need the `config/certs/ca.crt` file before their browser will trust the connection.
>
> Get it off the server by running this **on your own computer** (not the server):
> ```sh
> scp root@<YOUR_DROPLET_IP>:~/mqtt-broker-aroughidea/config/certs/ca.crt .
> ```
> Share the file via email, Slack, a shared folder, or a USB drive. Participants follow the CA trust instructions in CLIENT_SETUP.md before they can connect.
>
> Use the droplet IP address (not a domain name) in all connection settings, and add the `ca.crt` file to the CA Certificate field in MQTT Explorer.

---

## Troubleshooting

**"Connection refused" error**
- Is the container running? → `docker ps`
- Are firewall ports open? → `sudo ufw status`

**"Certificate error" or "hostname mismatch"**
- With **Let's Encrypt certs**: make sure the domain name in `mosquitto.conf` matches the hostname participants use. If you changed the domain after issuance, re-run certbot.
- With **self-signed certs**: the cert defaults to `localhost`. If clients connect by IP, regenerate certs with the IP as the CN/SAN:
  ```sh
  CERT_CN=<your_droplet_ip> CERT_SAN_IP_1=<your_droplet_ip> ./scripts/generate-certs.sh
  docker compose restart mosquitto
  ```
  Then redistribute the new `ca.crt`.
- Browser WSS connections are stricter than desktop tools.

**"Invalid password" or "not authorized"**
- Check broker logs: `docker logs -f mosquitto`
- Make sure the username in `config/acl` matches the one you created in Step 6.

**Tests fail on macOS/Windows**
- The test scripts need `MQTT_HOST=host.docker.internal`. Set that environment variable before running.

**Windows: Trusting the CA for `wss://` (self-signed certs only)**

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
3. Point your domain's A record to the new droplet IP, then re-run certbot (if using Let's Encrypt). Or regenerate self-signed certs if using those.
4. Recreate passwords if you want a fresh start.

To reset for a new workshop: delete `config/passwords`, `config/certs/`, and `data/`, then repeat Steps 6–8.

---

## Security Notes

- **Passwords** (`config/passwords`) and **certificates** (`config/certs/`) are excluded from git — they are generated at runtime.
- **Never commit these files** to the repository.
- If a password or certificate may have been exposed, regenerate it immediately and restart the broker.
- **Let's Encrypt private keys** (`/etc/letsencrypt/live/*/privkey.pem`) live outside the repo and are managed by certbot. Keep the `/etc/letsencrypt/` directory accessible only to root.
- For self-signed setups, the `ca.key` file in `config/certs/` is excluded from git but must be kept safe — anyone with it could impersonate your broker.
