# Next

Updated: 2026-11-26

## Where it stands

A portable MQTT broker on Eclipse Mosquitto in Docker, for prototyping, small workshops and deployments that can be reset. The README walks an organizer from a new server to TLS and a running broker, and a participant to connecting. CI with smoke tests passes; the last work, in May 2026, made those smoke tests reliable and set least-privilege CI permissions.

## Next step

Look at closed pull request #12 ("docs: align guides with current project state", one commit ahead of `main`, touching `README.md`, `PRODUCTION_RUNBOOK.md` and `certs/README.md`). If its changes are still wanted, open them again as a new pull request; then delete the leftover `copilot/*` branches.

## After that

- Before the next workshop, run README Step 10 ("Verify Everything Works") against the broker that will be used.

## Blocked or waiting

- None.

## Open questions

- Is a broker running now, and for which workshop?
- This plan was drafted by Claude on 2026-11-22 from the code and its history. Is the next step right?
- A direction to consider (noted from the Project Register, 2026-11-26): an MCP server, so Claude and other agents can publish to and listen on the broker's topics, so an agent can talk to devices (with LingoLink and the IoT Agents project's platformio-mcp). The register's own server is a template: the owner's sign-in through WorkOS, read-only first, every answer saying when it was read. Not decided.
