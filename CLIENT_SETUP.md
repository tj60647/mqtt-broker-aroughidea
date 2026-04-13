# Connecting a p5.js Client to Your DigitalOcean Broker (WSS)

This guide configures your broker and p5.js client to use secure WebSockets (`wss://`) on port `9001`.

> This is a client-focused guide. For full DigitalOcean server provisioning and deployment steps (droplet creation, Docker install, firewall, etc.), use [README.md](README.md).

> **Who should read which phase?**
>
> | Phase | For whom | What it covers |
> |---|---|---|
> | **Phase 1** | Workshop **organizer** | Final server-side checklist — run these steps on your droplet before distributing this file to participants |
> | **Phase 2** | Workshop **participant** | Everything needed to connect a p5.js sketch to the running broker |
>
> If you are a **participant** and your organizer has already set up the broker, skip directly to [Phase 2](#phase-2-update-your-p5js-script). Your organizer should give you the broker IP address, a username/password, and the `ca.crt` file.

## Phase 1: Server-Side Configuration

> **Note for organizers:** Phase 1 exists here as a compact server-readiness checklist. It covers only the steps that are directly required for p5.js / WebSocket clients to work (ACL, certificates, user account, and starting the broker). For full provisioning detail (droplet creation, Docker install, firewall setup, verification scripts) refer to [README.md](README.md). Once you have completed Phase 1, share this document — or just Phase 2 — with your participants.

Connect to your DigitalOcean droplet via SSH to perform these steps.

### 1. Prepare Configuration Files
The broker needs an Access Control List (ACL) to define permissions. Run the following commands to get to the repository root:
```bash
cd mqtt-broker-aroughidea
cp config/acl.example config/acl
```

### 2. Generate Certificates
The broker uses TLS for both MQTT over TLS (`8883`) and secure WebSockets (`9001`). Mosquitto will fail to start if the certificate files referenced in `mosquitto.conf` do not exist.

Generate a set of certificates:
```bash
./scripts/generate-certs.sh
```

### 3. Create an MQTT User
Anonymous access is disabled by default. You need to create a user before starting the broker.
For the default ACL and test scripts to work out-of-the-box, we recommend using the username `workshop-user`.

Run the following command:
```bash
docker run --rm -it \
    --user 1883:1883 \
    -v "$PWD/config:/mosquitto/config" \
    eclipse-mosquitto:2 \
    sh -lc 'mosquitto_passwd -c /mosquitto/config/passwords workshop-user'
```

*   You will be prompted to enter a password twice.
*   **Security:** Do not use a weak or default password on a publicly accessible server. Choose a strong, unique password. The test scripts read credentials from environment variables `MQTT_USER` and `MQTT_PASS`, so you can override the defaults without editing the scripts.

### 4. Start the Broker
Launch the broker container in the background.
```bash
docker compose up -d
```

### 5. Verify Server Setup
Before moving to the client code, verify that your ACLs and user are correctly configured.

**A. Verify ACL File**
```bash
ls -l config/acl
```

**B. Run the Test Script**
```bash
./scripts/test-connection.sh
```

*   If successfully configured, you will see: `✅ SUCCESS: Message received!`
*   If it fails, check that your created user matches the one in `config/acl` and `scripts/test-connection.sh`.

---

## Phase 2: Update Your p5.js Script

Open your p5.js script code and make the following changes.

### 1. Update the Host URL
Find the line defining `mqttBrokerHost`. Use `wss://` and port `9001`.

```javascript
// REPLACE <YOUR_DROPLET_IP> with your actual DigitalOcean IPv4 address.
// Example: let mqttBrokerHost = 'wss://192.168.1.100:9001';
let mqttBrokerHost = 'wss://<YOUR_DROPLET_IP>:9001';
```

### 2. Add Authentication Options
Find `setupMqttClient()` and pass credentials in the options object.

```javascript
function setupMqttClient() {
    const options = {
        username: 'myuser',
        password: 'mypassword',
        keepalive: 60,
        protocol: 'wss',
        clean: true,
        connectTimeout: 30 * 1000
    };

    mqttClient = mqtt.connect(mqttBrokerHost, options);

    // ... rest of the function ...
}
```

---

## Troubleshooting

### TLS / Certificate Errors in Browser
Browser clients require a trusted certificate chain for `wss://`.

*   For production browser clients, use a domain with a CA-signed certificate (for example, Let's Encrypt).
*   If using self-signed certs, ensure the CA is trusted on the client machine and certificate hostnames match the URL used in `mqttBrokerHost`.

### Windows: Trust the Local CA for `wss://localhost:9001`
Run PowerShell **as Administrator** in the repo root:

```powershell
certutil -addstore -f Root .\config\certs\ca.crt
```

Then fully restart the browser (all windows) and retry the client connection.

If you regenerate certs, re-import the CA and restart the browser again.

### Connection Refused?
*   Check that port **9001** is open on your DigitalOcean firewall.
*   Ensure the Docker container is running: `docker compose ps`
*   Check the logs for errors: `docker compose logs -f mosquitto`
