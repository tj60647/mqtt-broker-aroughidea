This directory contains Mosquitto configuration files.

Files:
- mosquitto.conf : Main broker configuration
- acl.example    : Example access control list (ACL)

Notes:
- `mosquitto.conf`: Main broker configuration. It references paths *inside* the container.
- Browser clients use secure WebSockets (`wss://`) on port `9001`.
- `acl`: Defines who can read/write which topics.
- `passwords`: Created by `mosquitto_passwd` tool (not committed to git).

For usage instructions, see the main [README.md](../README.md).

