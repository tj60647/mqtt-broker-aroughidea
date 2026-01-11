# Copilot Instructions

## Project Overview
This repository defines a portable, single-node MQTT broker infrastructure using Eclipse Mosquitto.
It is an **infrastructure repository**, not an application code repository.
The target deployment is a single VPS (e.g., DigitalOcean) using basic Docker Compose.

## Principles & Philosophy
- **Infrastructure as Code:** All configuration (ACLs, broker settings) must be versioned, except secrets.
- **Simplicity:** Favor explicit configuration files over complex scripts or abstractions. "Boring is good."
- **Ephemerality:** The broker should be easy to destroy and recreate. State is stored in `./data`, but the architecture assumes a single node.
- **Security:**
  - **No Secrets in Git:** Never commit passwords, keys, or certificates.
  - **Auth Required:** Username/password authentication is mandatory (no anonymous access).
  - **TLS Supported:** Configuration must support TLS (port 8883) via mounted certificates.

## Architecture & Data Flow
- **Root:** `docker-compose.yml` orchestrates the single broker container.
- **Config:** `./config/` is mounted to `/mosquitto/config`.
  - `mosquitto.conf` references paths as they appear *inside* the container (e.g., `/mosquitto/config/certs/server.crt`).
  - `acl` defines topic permissions per user.
- **Secrets:** `./config/passwords` and `./certs/*.{key,crt}` are generated at runtime and ignored by git.
- **Persistence:** `./data` (state) and `./log` are mounted for persistence/debugging.

## Developer Workflows

### Setup & Provisioning
- **Certificates:** Users must generate CA and Server certs into `config/certs/`. Do not assume they exist.
- **Passwords:** Users generate passwords using `mosquitto_passwd` inside the container (see `README.md`).

### Common Commands
- **Start:** `docker compose up -d`
- **Logs:** `docker logs -f mosquitto`
- **Reload Config:** `docker kill -s HUP mosquitto` (Use this instead of restarting for config changes when possible).

## Conventions
- **Paths:** Always use relative paths from repo root in documentation and scripts.
- **Docker:**
  - Use `eclipse-mosquitto:2` (pinned major version).
  - Avoid `network_mode: host` unless strictly necessary; map ports `1883`, `8883`, `9001` explicitly.
- **Scripts:** Place utility scripts in `scripts/`. Keep them POSIX-compliant headers (`#!/bin/sh`) if possible, or `#!/bin/bash` if arrays are needed.

## Cross-Component Integration
- The broker listens on:
  - `0.0.0.0:1883` (Cleartext - firewall restricts this in production usually)
  - `0.0.0.0:8883` (TLS - public facing)
- ACLs link specific usernames to topic patterns. When suggesting ACL changes, verify they match the user model (e.g., `user alice` -> `topic readwrite workshop/alice/#`).
