# Production Runbook — MQTT Broker (DigitalOcean)

This document is the single source of truth for operating and hardening this broker in production. It covers the completed WSS-only migration, the path to publicly trusted certificates, renewal automation, validation, and rollback. All procedural detail is preserved here so this document can stand alone during delivery.

---

## Overview

| Topic | Summary |
|---|---|
| Target environment | Single-node DigitalOcean droplet, Docker Compose |
| Broker | Eclipse Mosquitto `eclipse-mosquitto:2` |
| Listeners | `1883` plaintext · `8883` MQTTS · `9001` WSS |
| Auth | Username/password required; no anonymous access |
| Cert strategy (recommended) | Let's Encrypt via `certbot` — publicly trusted, no CA file to distribute |
| Cert strategy (fallback) | Self-signed CA + server cert generated at runtime — requires participants to install `ca.crt` |

---

## Part 1 — WSS-Only Migration (Completed)

### Goals
- Keep architecture single-container and explicit.
- Require TLS for all browser MQTT traffic.
- Keep onboarding steps consistent across all docs.

### Phase 1: Broker Hardening (Completed)
- Enabled TLS on WebSocket listener (`9001`) in `config/mosquitto.conf`.
- Reused existing cert paths from the MQTTS listener (`8883`).
- Kept `allow_anonymous false` and ACL/password controls unchanged.

### Phase 2: Documentation Alignment (Completed)
- Updated all setup and client docs to use `wss://<HOST>:9001`.
- Clarified why certs are mounted directly in Mosquitto.
- Added clear note that browser clients need a trusted certificate chain.

### Phase 3: Operational Validation (Recommended)
- Restart broker and confirm listener startup without TLS errors.
- Validate MQTT over TLS (`8883`) with CLI client.
- Validate secure WebSockets (`9001`) with a browser client using trusted certs.

### Phase 4: Production Readiness (Recommended)
- Use a domain name and CA-signed certs (e.g., Let's Encrypt) for `wss://` browser reliability.
- Restrict plaintext `1883` to trusted networks only (or disable if unused).
- Maintain cert rotation and renewal playbook.

### Acceptance Criteria
- Broker starts with no TLS/listener errors.
- Docs never instruct `ws://` for browser clients.
- Firewall guidance explicitly maps `9001` to secure WebSockets.

---

## Part 2 — Trusted Certificates (Let's Encrypt)

Let's Encrypt is the recommended certificate strategy for this broker. Publicly trusted certificates eliminate the need to distribute a `ca.crt` file to participants and make browser WSS connections work without any trust bypass.

**Goal:** trusted TLS on `8883` (MQTTS) and `9001` (WSS).

### Phase 1: Prerequisites

#### 1. Domain and DNS
- Buy or use an existing domain (example: `example.com`).
- Create a DNS A record pointing to your droplet public IP:
  - `mqtt.example.com → <DROPLET_IP>`
- Verify propagation before running certbot:
  ```sh
  dig mqtt.example.com
  ```

#### 2. Network and Host Readiness
- Ensure ports are reachable:
  - `22` (SSH)
  - `80` (HTTP — required for HTTP-01 challenge; not needed for DNS-01)
  - `8883` and `9001` (broker listeners)
- Keep system time accurate (`timedatectl status`) to avoid TLS validation issues.

### Phase 2: Certificate Issuance (Let's Encrypt)

Choose one issuance method.

#### Option A — HTTP-01 (simplest; briefly uses port 80)

```sh
sudo apt install -y certbot
sudo certbot certonly --standalone \
  --non-interactive --agree-tos \
  -m your-email@example.com \
  -d mqtt.example.com
```

Certbot temporarily listens on port 80 to prove domain ownership and then exits. If port 80 is firewalled, use Option B.

#### Option B — DNS-01 via DigitalOcean API (no port 80; supports wildcards)

This method uses the DigitalOcean DNS API — port 80 is never touched and wildcard certificates are supported.

1. In the DigitalOcean control panel, go to **API → Tokens → Generate New Token**.
   - Name: `certbot-dns`
   - Grant **write** access to **domains** only.
   - Copy the token — you will not see it again.

2. Save the token to the droplet (outside git, root-readable only):
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
     -d mqtt.example.com
   ```

**Acceptance criteria:**
- `fullchain.pem` and `privkey.pem` exist under `/etc/letsencrypt/live/mqtt.example.com/`.
- Chain validates publicly: `openssl s_client -connect mqtt.example.com:8883 -CAfile /etc/ssl/certs/ca-certificates.crt`

### Phase 3: Wire Trusted Certs into Mosquitto

#### 1. Mount cert paths into container

Add a read-only bind mount in `docker-compose.yml`:

```yaml
volumes:
  - /etc/letsencrypt:/etc/letsencrypt:ro
```

#### 2. Update listener TLS paths in `config/mosquitto.conf`

Use CA-signed files for both TLS listeners:

```
certfile /etc/letsencrypt/live/<name>/fullchain.pem
keyfile  /etc/letsencrypt/live/<name>/privkey.pem
```

Keep `cafile` only if required for your trust model; for public CA certificates, `fullchain.pem` is typically sufficient for server presentation.

#### 3. Reload/restart broker

Apply with restart:

```sh
docker compose up -d
```

Or use SIGHUP if you have confirmed that cert reload works without a full restart:

```sh
docker kill -s HUP mosquitto
```

**Acceptance criteria:**
- Broker starts cleanly.
- `wss://mqtt.example.com:9001` and `mqtts://mqtt.example.com:8883` present trusted certificates in client tools.

### Phase 4: Renewal Automation

#### 1. Auto-renew certificates

Configure certbot timer/cron:

```sh
certbot renew
```

#### 2. Post-renew hook

Add a deploy hook to reload the broker after successful renewal:

```sh
docker kill -s HUP mosquitto
# or
docker compose restart mosquitto
```

This repo includes a helper script: `scripts/renew-certs-and-reload.sh`

```sh
# Make executable
chmod +x scripts/renew-certs-and-reload.sh

# Run manually or from cron on the droplet
./scripts/renew-certs-and-reload.sh
```

#### 3. Recommended automation via systemd timer

Unit files are provided in `scripts/systemd/`. Install on droplet:

```sh
sudo cp scripts/systemd/mqtt-cert-renew.service /etc/systemd/system/
sudo cp scripts/systemd/mqtt-cert-renew.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now mqtt-cert-renew.timer
```

Verify the timer is active:

```sh
systemctl status mqtt-cert-renew.timer
systemctl list-timers --all | grep mqtt-cert-renew
```

Run once manually to confirm the hook works:

```sh
sudo systemctl start mqtt-cert-renew.service
journalctl -u mqtt-cert-renew.service -n 100 --no-pager
```

#### 4. Alerting

- Add simple expiry checks (weekly) and alert if cert validity < 20 days.

**Acceptance criteria:**
- Dry-run renewal succeeds: `certbot renew --dry-run`
- Broker reload hook executes successfully.

### Phase 5: Validation and Cutover

#### 1. External TLS checks
- Validate chain and hostname from outside the droplet.
- Verify no self-signed artifacts remain in production listener cert paths.

#### 2. Client validation
- Browser test to `wss://mqtt.example.com:9001` with no trust warnings.
- CLI/tooling test for `8883` auth + publish/subscribe.

#### 3. Security hardening
- Restrict plaintext `1883` via firewall or disable if not required.
- Keep `allow_anonymous false` and ACL controls.

---

## Rollback Plan

- Keep prior self-signed files and a previous `mosquitto.conf` snapshot before cutting over.
- If the cutover fails:
  1. Restore previous cert paths and config.
  2. Restart broker: `docker compose up -d`
  3. Confirm client recovery by running smoke tests.

---

## Operational Checklist

- [ ] DNS points to droplet and has propagated.
- [ ] Let's Encrypt cert issued for production hostname.
- [ ] `docker-compose.yml` mounts cert location read-only.
- [ ] `mosquitto.conf` uses CA-trusted cert/key paths.
- [ ] Renewal + reload automation in place.
- [ ] `wss://` browser test passes without trust bypass.
- [ ] `8883` MQTTS smoke test passes.
- [ ] Plaintext `1883` restricted to internal network or disabled.
- [ ] Alerting configured for cert expiry < 20 days.

---

## Glossary

| Term | Definition |
|---|---|
| **ACL** | Access Control List. A file (`config/acl`) that maps usernames to permitted MQTT topics and actions (read, write, readwrite). |
| **ACME** | Automated Certificate Management Environment. The protocol used by Let's Encrypt to issue and renew certificates. |
| **A record** | A DNS record type that maps a hostname (e.g., `mqtt.example.com`) to an IPv4 address. |
| **CA (Certificate Authority)** | An entity that signs certificates to establish trust. In the workshop setup, a local self-signed CA is generated. In production, Let's Encrypt is the CA. |
| **certbot** | The official Let's Encrypt client used to request and renew certificates via the ACME protocol. |
| **cert rotation** | The process of replacing an expiring or compromised certificate with a new one without downtime. |
| **DNS-01** | An ACME challenge type that proves domain ownership by creating a DNS TXT record. Required for wildcard certificates or hosts without a public HTTP endpoint. |
| **Docker Compose** | A tool for defining and running multi-container Docker applications from a `docker-compose.yml` file. |
| **droplet** | DigitalOcean's term for a virtual private server (VPS). |
| **fullchain.pem** | A Let's Encrypt file containing the server certificate plus the full intermediate CA chain. Used as `certfile` in Mosquitto. |
| **HTTP-01** | An ACME challenge type that proves domain ownership by serving a file over HTTP on port 80. The simplest method when port 80 is available. |
| **MQTTS** | MQTT over TLS. Runs on port `8883` by convention. Used by CLI tools and native app clients. |
| **Mosquitto** | Eclipse Mosquitto — the open-source MQTT message broker used in this project. |
| **MQTT** | Message Queuing Telemetry Transport. A lightweight publish/subscribe messaging protocol designed for IoT and constrained devices. |
| **privkey.pem** | A Let's Encrypt file containing the server's private key. Used as `keyfile` in Mosquitto. Keep this file private and outside git. |
| **SAN (Subject Alternative Name)** | An X.509 extension that lists additional hostnames or IP addresses covered by a certificate. |
| **self-signed certificate** | A certificate signed by its own private key rather than a public CA. Trusted only by clients that explicitly import the CA cert. Suitable for workshops; not for production browsers. |
| **SIGHUP** | A Unix signal sent to a process to instruct it to reload its configuration. `docker kill -s HUP mosquitto` triggers a config reload without fully restarting the broker. |
| **systemd timer** | A systemd unit that schedules another unit (e.g., a service) to run at specified intervals, similar to cron but integrated with the journal. |
| **TLS (Transport Layer Security)** | A cryptographic protocol that provides encrypted communication over a network. Formerly known as SSL. |
| **WSS** | WebSocket Secure. WebSocket protocol over TLS. Used by browser clients connecting to the broker on port `9001`. |
