# Connecting a p5.js Client to Your DigitalOcean Broker (WSS)

This guide configures your broker and p5.js client to use secure WebSockets (`wss://`) on port `9001`.

## Phase 1: Server-Side Configuration

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

### 3. Start the Broker
Launch the broker container in the background.
```bash
docker compose up -d
```

### 4. Create an MQTT User
Anonymous access is disabled by default. You need to create a user.
For the default ACL and test scripts to work out-of-the-box, we recommend using the username `workshop-user`.

Run the following command:
```bash
docker compose exec mosquitto mosquitto_passwd -c /mosquitto/config/passwords workshop-user
```

*   You will be prompted to enter a password twice.
*   **Tip:** The included test script assumes the password is `mqtt-fun-2026`. Use that for simplicity, or update the script if you choose your own.

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

### Connection Refused?
*   Check that port **9001** is open on your DigitalOcean firewall.
*   Ensure the Docker container is running: `docker compose ps`
*   Check the logs for errors: `docker compose logs -f mosquitto`
