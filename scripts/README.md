Utility scripts for provisioning the broker.

Scripts should:
- Be explicit and readable
- Avoid side effects outside this repository
- Never embed secrets

Typical uses:
- Creating Mosquitto password files
- Generating local CA and server certificates for `8883` (MQTTS) and `9001` (WSS)
- Running deployment smoke tests (`test-connection.sh` for `1883`, `test-mqtts.sh` for `8883`, `test-wss.sh` for `9001`)
