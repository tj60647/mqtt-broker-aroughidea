This directory intentionally contains no certificates or keys.

TLS materials are generated per deployment and must not be committed.
These certificates are used by both listeners:
- `8883` (MQTTS)
- `9001` (WSS / secure WebSockets)

Expected files at runtime:
- ca.crt
- server.crt
- server.key

These are referenced by mosquitto.conf but ignored by Git.
