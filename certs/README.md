This directory intentionally contains no certificates or keys.

TLS materials for this project are generated into `config/certs/` (not here) and
are mounted into the container via the `./config:/mosquitto/config` volume in
`docker-compose.yml`.  `mosquitto.conf` references them as
`/mosquitto/config/certs/ca.crt`, `/mosquitto/config/certs/server.crt`, and
`/mosquitto/config/certs/server.key`.

To generate self-signed certs in the correct location, run:
```sh
./scripts/generate-certs.sh
```

This top-level `certs/` directory exists only so that `config/certs/` entries
in `.gitignore` do not accidentally shadow the path — actual runtime files
belong in `config/certs/`.
