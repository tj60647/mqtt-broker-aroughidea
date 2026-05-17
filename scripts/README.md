Utility scripts for provisioning the broker.

Scripts should:
- Be explicit and readable
- Avoid side effects outside this repository
- Never embed secrets

Typical uses:
- Checking that all required runtime files exist (`preflight-check.sh`) — run this before `docker compose up`
- Creating Mosquitto password files
- Generating local CA and server certificates for `8883` (MQTTS) and `9001` (WSS)
- Running deployment smoke tests (`test-connection.sh` for `1883`, `test-mqtts.sh` for `8883`, `test-wss.sh` for `9001`)
- Renewing trusted certs and reloading Mosquitto on droplet (`renew-certs-and-reload.sh`)

`generate-certs.sh` also reassigns `server.key` to the container's Mosquitto user (`uid 1883`) so the broker can read the private key without loosening its file mode.

Debugging guidance:
- Prefer Docker-context diagnostics for TLS issues (`docker exec mosquitto ...` or `docker run ... --network <compose_network>`).
- After any cert rotation, reload/restart broker before smoke tests (`docker kill -s HUP mosquitto` or `docker compose restart mosquitto`).

Systemd automation units (for DigitalOcean droplet) are in `scripts/systemd/`:
- `mqtt-cert-renew.service`
- `mqtt-cert-renew.timer`
