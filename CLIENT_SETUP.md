# Connecting a p5.js Client to Your DigitalOcean Broker

This guide explains how to configure your DigitalOcean Mosquitto broker to accept connections from your p5.js script.

## Phase 1: Server-Side Configuration

Connect to your DigitalOcean droplet via SSH to perform these steps.

### 1. Prepare Configuration Files
The broker needs an Access Control List (ACL) to define permissions. Run the following commands to get to the repository root:
```bash
cd mqtt-broker-aroughidea
cp config/acl.example config/acl
```

### 2. Generate Certificates
The broker configuration (`mosquitto.conf`) enables a secure listener on port 8883 by default. Even if you only plan to use WebSockets (port 9001) for this test, Mosquitto will fail to start if the certificate files referenced in the config do not exist.

We can generate a set of temporary, self-signed certificates to satisfy this requirement:
```bash
./scripts/generate-certs.sh
```
*   **Note:** These certificates are generated with a 10-year validity, so they are effectively "long-term" for this project. They are self-signed, which is sufficient for starting the server. For a public production application using Secure WebSockets (WSS), you would need valid certificates from a trusted authority (like Let's Encrypt).

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
*   **Tip:** The included test script assumes the password is `mqtt-fun-2026`. Use that for simplicity, or remember to update the test script later if you choose your own.

### 5. Verify Server Setup
Before moving to the client code, verify that your ACLs and user are correctly configured.

**A. Verify ACL File**
Check that the ACL file was copied correctly:
```bash
ls -l config/acl
```

**B. Run the Test Script**
We have included a script that runs a publisher and subscriber inside Docker to self-test the broker.
```bash
./scripts/test-connection.sh
```
*   If successfully configured, you will see: `✅ SUCCESS: Message received!`
*   If it fails, check that your created user matches the one in `config/acl` and `scripts/test-connection.sh`.

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
