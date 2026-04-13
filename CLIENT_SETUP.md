# Participant Setup — Connecting to the Workshop Broker

This guide is for **workshop participants**. Your organizer has already set up the broker — you just need to connect your p5.js sketch to it.

**Before you start, your organizer should have given you:**

| | |
|---|---|
| Broker IP | e.g. `203.0.113.10` |
| Username | e.g. `workshop-user` |
| Password | e.g. `mqtt-fun-2026` |
| CA certificate file | `ca.crt` |

If you are an organizer setting up the broker for the first time, see [README.md](README.md) instead.

---

## Step 1: Trust the CA Certificate

Your browser needs the `ca.crt` file to trust the broker's self-signed certificate.

**Windows**

Run PowerShell **as Administrator** in the folder where you saved `ca.crt`:

```powershell
certutil -addstore -f Root .\ca.crt
```

Then close and reopen your browser completely.

**macOS**

```sh
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ca.crt
```

Then restart your browser.

**Linux**

Copy the cert to the system trust store and update it:

```sh
sudo cp ca.crt /usr/local/share/ca-certificates/mqtt-workshop-ca.crt
sudo update-ca-certificates
```

Then restart your browser.

---

## Step 2: Update Your p5.js Sketch

Open your p5.js sketch and make the following two changes.

### 1. Set the broker URL

Find the line defining `mqttBrokerHost` and replace it with your organizer's IP address:

```javascript
// Use wss:// and port 9001 for secure WebSockets
// Example: let mqttBrokerHost = 'wss://203.0.113.10:9001';
let mqttBrokerHost = 'wss://<YOUR_BROKER_IP>:9001';
```

### 2. Add your credentials

Find `setupMqttClient()` and add your username and password to the options object:

```javascript
function setupMqttClient() {
    const options = {
        username: 'workshop-user',  // replace with credentials from your organizer
        password: 'mqtt-fun-2026',  // replace with credentials from your organizer
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

### Certificate error or "your connection is not private"

- Make sure you completed Step 1 and **fully restarted** your browser (all windows).
- If you regenerated certs or received a new `ca.crt`, repeat Step 1.
- On Windows, if the error persists, run `certutil -delstore Root mqtt-workshop-ca` first, then re-add it.

### "Connection refused" or sketch won't connect

- Double-check that you used `wss://` (not `ws://`) and port `9001`.
- Confirm the broker IP with your organizer.
- Try opening `https://<YOUR_BROKER_IP>:9001` in your browser — if you see a certificate warning instead of a blank page, your cert is not yet trusted (go back to Step 1).

### Credentials rejected

- Check for typos in username and password — they are case-sensitive.
- Ask your organizer to confirm the credentials.
