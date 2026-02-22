Utility scripts for provisioning the broker.

Scripts should:
- Be explicit and readable
- Avoid side effects outside this repository
- Never embed secrets

Typical uses:
- Creating Mosquitto password files
- Generating local CA and server certificates for `8883` (MQTTS) and `9001` (WSS)
- Running deployment smoke tests (`test-connection.sh` for `1883`, `test-mqtts.sh` for `8883`, `test-wss.sh` for `9001`)
- Renewing trusted certs and reloading Mosquitto on droplet (`renew-certs-and-reload.sh`)

Debugging guidance:
- Prefer Docker-context diagnostics for TLS issues (`docker exec mosquitto ...` or `docker run ... --network <compose_network>`).
- After any cert rotation, reload/restart broker before smoke tests (`docker kill -s HUP mosquitto` or `docker compose restart mosquitto`).

Systemd automation units (for DigitalOcean droplet) are in `scripts/systemd/`:
- `mqtt-cert-renew.service`
- `mqtt-cert-renew.timer`
