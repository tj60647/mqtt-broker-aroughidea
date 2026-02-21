# Trusted Certificates Roadmap (DigitalOcean)

This roadmap moves the broker from self-signed certificates to publicly trusted certificates for production clients (especially browsers using `wss://`).

## Scope
- Target: single-node DigitalOcean droplet with Docker Compose.
- Broker: Eclipse Mosquitto.
- Goal: trusted TLS on `8883` (MQTTS) and `9001` (WSS).

## Phase 1: Prerequisites

### 1. Domain and DNS
- Buy or use an existing domain (example: `example.com`).
- Create DNS records pointing to your droplet public IP:
  - `mqtt.example.com` (A record)
  - Optional: `wss.example.com` (A record)

### 2. Network and Host Readiness
- Ensure ports are reachable:
  - `22` (SSH)
  - `80` (HTTP, needed for ACME HTTP-01 if using certbot standalone/nginx)
  - `443` (optional, if you host web apps/reverse proxy)
  - `8883` and `9001` (broker listeners)
- Keep system time accurate (`timedatectl status`) to avoid TLS validation issues.

## Phase 2: Certificate Issuance (Let’s Encrypt)

Choose one issuance pattern.

### Option A (simple): Certbot on droplet
- Install certbot.
- Request cert for `mqtt.example.com` (and any additional SAN names you need).
- Store under `/etc/letsencrypt/live/<name>/`.

### Option B (DNS challenge)
- Use DNS-01 if you cannot expose port `80` or need wildcard certs.
- Configure provider plugin/API credentials securely outside git.

Acceptance criteria:
- `fullchain.pem` and `privkey.pem` exist.
- Chain validates publicly.

## Phase 3: Wire Trusted Certs into Mosquitto

### 1. Mount cert paths into container
- Add read-only bind mount in `docker-compose.yml`, for example:
  - `/etc/letsencrypt:/etc/letsencrypt:ro`

### 2. Update listener TLS paths in `config/mosquitto.conf`
- Use CA-signed files for both TLS listeners:
  - `certfile /etc/letsencrypt/live/<name>/fullchain.pem`
  - `keyfile /etc/letsencrypt/live/<name>/privkey.pem`
- Keep `cafile` only if required for your trust model; for public CA certificates, `fullchain.pem` is typically sufficient for server presentation.

### 3. Reload/restart broker
- Apply with restart (`docker compose up -d`) or SIGHUP if path/cert reload behavior is known and tested.

Acceptance criteria:
- Broker starts cleanly.
- `wss://mqtt.example.com:9001` and `mqtts://mqtt.example.com:8883` present trusted certificates in client tools.

## Phase 4: Renewal Automation

### 1. Auto-renew certificates
- Configure certbot timer/cron (`certbot renew`).

### 2. Post-renew hook
- Add deploy hook to reload broker after successful renewal:
  - `docker kill -s HUP mosquitto` or `docker compose restart mosquitto`
- This repo includes helper script: `scripts/renew-certs-and-reload.sh`
  - Make executable: `chmod +x scripts/renew-certs-and-reload.sh`
  - Run manually/cron on droplet: `./scripts/renew-certs-and-reload.sh`

### 3. Recommended automation via systemd timer
- Unit files are provided in `scripts/systemd/`.
- Install on droplet:

```sh
sudo cp scripts/systemd/mqtt-cert-renew.service /etc/systemd/system/
sudo cp scripts/systemd/mqtt-cert-renew.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now mqtt-cert-renew.timer
```

- Verify:

```sh
systemctl status mqtt-cert-renew.timer
systemctl list-timers --all | grep mqtt-cert-renew
```

- Run once manually:

```sh
sudo systemctl start mqtt-cert-renew.service
journalctl -u mqtt-cert-renew.service -n 100 --no-pager
```

### 3. Alerting
- Add simple expiry checks (weekly) and alert if cert validity < 20 days.

Acceptance criteria:
- Dry-run renewal succeeds (`certbot renew --dry-run`).
- Broker reload hook executes successfully.

## Phase 5: Validation and Cutover

### 1. External TLS checks
- Validate chain and hostname from outside droplet.
- Verify no self-signed artifacts remain in production listener cert paths.

### 2. Client validation
- Browser test to `wss://mqtt.example.com:9001` with no trust warnings.
- CLI/tooling test for `8883` auth + publish/subscribe.

### 3. Security hardening
- Restrict plaintext `1883` via firewall or disable if not required.
- Keep `allow_anonymous false` and ACL controls.

## Rollback Plan
- Keep prior self-signed files and previous `mosquitto.conf` snapshot.
- If cutover fails:
  1. Restore previous cert paths/config.
  2. Restart broker.
  3. Confirm client recovery.

## Operational Checklist
- [ ] DNS points to droplet and has propagated.
- [ ] Let’s Encrypt cert issued for production hostname.
- [ ] `docker-compose.yml` mounts cert location read-only.
- [ ] `mosquitto.conf` uses CA-trusted cert/key paths.
- [ ] Renewal + reload automation in place.
- [ ] `wss://` browser test passes without trust bypass.
- [ ] `8883` MQTTS smoke test passes.