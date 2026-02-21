# WSS-Only Roadmap

This roadmap tracks the move to secure WebSockets-only (`wss://`) for browser clients while keeping the broker simple and single-node.

## Goals
- Keep architecture single-container and explicit.
- Require TLS for all browser MQTT traffic.
- Keep onboarding steps consistent across all docs.

## Phase 1: Broker Hardening (Completed)
- Enable TLS on WebSocket listener (`9001`) in `config/mosquitto.conf`.
- Reuse existing cert paths from the MQTTS listener (`8883`).
- Keep `allow_anonymous false` and ACL/password controls unchanged.

## Phase 2: Documentation Alignment (Completed)
- Update all setup and client docs to use `wss://<HOST>:9001`.
- Clarify why certs are mounted directly in Mosquitto.
- Add clear note that browser clients need a trusted certificate chain.

## Phase 3: Operational Validation (Recommended)
- Restart broker and confirm listener startup without TLS errors.
- Validate MQTT over TLS (`8883`) with CLI client.
- Validate secure WebSockets (`9001`) with a browser client using trusted certs.

## Phase 4: Production Readiness (Recommended)
- Use a domain name and CA-signed certs (e.g., Let's Encrypt) for `wss://` browser reliability.
- Restrict plaintext `1883` to trusted networks only (or disable if unused).
- Maintain cert rotation and renewal playbook.

## Acceptance Criteria
- Broker starts with no TLS/listener errors.
- Docs never instruct `ws://` for browser clients.
- Firewall guidance explicitly maps `9001` to secure WebSockets.
