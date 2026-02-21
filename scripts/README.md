Utility scripts for provisioning the broker.

Scripts should:
- Be explicit and readable
- Avoid side effects outside this repository
- Never embed secrets

Typical uses:
- Creating Mosquitto password files
- Generating local CA and server certificates for `8883` (MQTTS) and `9001` (WSS)
