# wss-monitoring — GHCR image

`ghcr.io/willemstein-smart-services/wss-monitoring:<tag>` — Uptime Kuma + ttyd webterminal.

## Wat er anders is t.o.v. de oude compose
- apt + ttyd + user -> **build-time** (was: elke boot opnieuw -> trage reboot)
- Uptime Kuma is **voorgebakken** in de image (`/opt/uptime-kuma`, incl. npm install);
  eerste boot kopieert naar de volume i.p.v. minuten npm-installeren
- `npm run setup` op volume blijft de `.wss-installed`-flag
- env `MONITOR_WEB_PASSWORD` blijft runtime (secret, nooit in image)

## Compose na overgang
```yaml
wss-monitoring:
  image: ghcr.io/willemstein-smart-services/wss-monitoring:1.0
  container_name: wss-monitoring
  hostname: wss-monitoring
  restart: unless-stopped
  environment:
    TZ: Europe/Amsterdam
    MONITOR_WEB_PASSWORD: "VERVANG_DOOR_STERK_WACHTWOORD"
  volumes:
    - /volume1/docker/wss_monitoring:/home/monitor
  stdin_open: true
  tty: true
  networks:
    docker_network:
      ipv4_address: 192.168.10.62
```
(entrypoint.sh zit in de image -> `command:`-blok weg)

## Let op
- Volume met bestaande kuma blijft gewoon werken (kopieert niks over bestaand)
- `git fetch --tags` bij elke boot is non-fatal
- Release-flow = zelfde als wss-devin: bump version-label, push, tag volgt
