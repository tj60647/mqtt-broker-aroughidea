# Participant Setup — Connecting to the Workshop Broker

This guide is for **workshop participants**. Your organizer has already set up the broker — you just need to connect your p5.js sketch to it.

**Before you start, your organizer should have given you:**

| | |
|---|---|
| Broker address | e.g. `mqtt.example.com` or `203.0.113.10` |
| Username | e.g. `workshop-user` |
| Password | e.g. `mqtt-fun-2026` |

> **Did your organizer also give you a `ca.crt` file?** If yes, install it first — see the optional step below. If not, skip straight to Step 1.

If you are an organizer setting up the broker for the first time, see [README.md](README.md) instead.

---

## Optional: Install a CA Certificate (self-signed certs only)

Skip this section if your organizer did **not** give you a `ca.crt` file.

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

## Step 1: Update Your p5.js Sketch

Open your p5.js sketch and make the following two changes.

### 1. Set the broker URL

Find the line defining `mqttBrokerHost` and replace it with your organizer's address:

```javascript
// Use wss:// and port 9001 for secure WebSockets
// Example (domain): let mqttBrokerHost = 'wss://mqtt.example.com:9001';
// Example (IP):     let mqttBrokerHost = 'wss://203.0.113.10:9001';
let mqttBrokerHost = 'wss://<YOUR_BROKER_ADDRESS>:9001';
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

- If your organizer gave you a `ca.crt` file: make sure you completed the optional CA install step above and **fully restarted** your browser (all windows).
- If you regenerated certs or received a new `ca.crt`, repeat the install step.
- On Windows, if the error persists after reinstalling, run `certutil -delstore Root mqtt-workshop-ca` first, then re-add it.
- If your organizer is using a Let's Encrypt certificate (no `ca.crt` given), this error usually means the domain name in your URL doesn't match what the certificate was issued for — confirm the address with your organizer.

### "Connection refused" or sketch won't connect

- Double-check that you used `wss://` (not `ws://`) and port `9001`.
- Confirm the broker address with your organizer.
- Try opening `https://<YOUR_BROKER_ADDRESS>:9001` in your browser — if you see a certificate warning instead of a blank page, your cert is not yet trusted (go back to the optional install step if you have a `ca.crt`).

### Credentials rejected

- Check for typos in username and password — they are case-sensitive.
- Ask your organizer to confirm the credentials.
