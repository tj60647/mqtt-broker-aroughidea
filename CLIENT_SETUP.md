# Connecting a p5.js Client to Your DigitalOcean Broker

This guide explains how to configure your DigitalOcean Mosquitto broker to accept connections from your p5.js script.

## Phase 1: Server-Side Configuration

Connect to your DigitalOcean droplet via SSH to perform these steps.

### 1. Prepare Configuration Files
The broker needs an Access Control List (ACL) to define permissions.
```bash
# From the repository root
cp config/acl.example config/acl
```

### 2. Generate Certificates
Even if you plan to use unencrypted WebSockets for testing, the broker configuration (`mosquitto.conf`) requires certificate files to be present on start up. We can generate self-signed ones easily:
```bash
./scripts/generate-certs.sh
```

### 3. Start the Broker
Launch the broker container in the background.
```bash
docker compose up -d
```

### 4. Create an MQTT User
Anonymous access is disabled by default for security. You need to create a username and password.
Run the following command (replace `myuser` with your desired username):

```bash
docker compose exec mosquitto mosquitto_passwd -c /mosquitto/config/passwords myuser
```

*   You will be prompted to enter a password twice.
*   **Remember these credentials.** You will need them for your script.

---

## Phase 2: Update Your p5.js Script

Open your p5.js script code and make the following changes to connect to your specific server.

### 1. Update the Host URL
Find the line defining `mqttBrokerHost`. Change it to use `ws://` (WebSocket) and port `9001`.

```javascript
// REPLACE <YOUR_DROPLET_IP> with your actual DigitalOcean IPv4 address.
// Example: let mqttBrokerHost = 'ws://192.168.1.100:9001';
let mqttBrokerHost = 'ws://<YOUR_DROPLET_IP>:9001';
```

### 2. Add Authentication Options
Find the `setupMqttClient()` function. You need to pass an `options` object to `mqtt.connect` containing your new username and password.

**Old Code:**
```javascript
function setupMqttClient() {
    mqttClient = mqtt.connect(mqttBrokerHost);
    // ...
```

**New Code:**
```javascript
function setupMqttClient() {
    // 1. Define connection options
    const options = {
        username: 'myuser',       // <--- The username you created in Phase 1
        password: 'mypassword',   // <--- The password you created in Phase 1
        keepalive: 60,
        protocol: 'ws',           // Force WebSocket protocol
        clean: true,
        connectTimeout: 30 * 1000
    };

    // 2. Pass options to the connect function
    mqttClient = mqtt.connect(mqttBrokerHost, options);

    // ... rest of the function ...
```

---

## Troubleshooting

### "Mixed Content" Errors
If you are hosting your p5.js sketch on a secure website (beginning with `https://`), the browser might block the connection to `ws://` (unsecure WebSocket).
*   **Quick Fix:** Host your p5.js sketch locally or on an `http://` page.
*   **Proper Fix:** Configure **WSS (Secure WebSockets)**. This requires a real domain name and valid SSL certificates (e.g., Let's Encrypt), which is outside the scope of this simple setup.

### Connection Refused?
*   Check that port **9001** is open on your DigitalOcean firewall (if you enabled one).
*   Ensure the Docker container is running: `docker compose ps`
*   Check the logs for errors: `docker compose logs -f mosquitto`
