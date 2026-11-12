# wss-logs — Grafana + Loki + Alloy

Centrale log-stack op de NAS. Drie officiële images, geen eigen build.

| Service | IP | URL |
|---|---|---|
| Grafana | 192.168.10.65 | http://192.168.10.65:3000 (admin) |
| Loki | 192.168.10.66 | intern (`wss-loki:3100`) |
| Alloy | 192.168.10.67 | http://192.168.10.67:12345 (collector-UI) |

## Eenmalig op de NAS

```sh
mkdir -p /volume1/docker/wss-grafana/{grafana,loki,alloy}
chmod 777 /volume1/docker/wss-grafana/grafana \
          /volume1/docker/wss-grafana/loki \
          /volume1/docker/wss-grafana/alloy
```

In Portainer: nieuwe stack `wss-logs`, inhoud van `docker-compose.yml`
plakken, `GF_SECURITY_ADMIN_PASSWORD` invullen, deployen.

## Hoe het werkt

- **Alloy** (.67) verzamelt: docker-logs via `docker.sock` (dekt ook
  Apache-stdout van wss-webserver), `/var/log/wss/*.log`, de mail-
  catcher, en de site-app-logs uit de backup-mirror.
- **Loki** (.66) bewaart 90 dagen op `/volume1/docker/wss-grafana/loki`.
- **Grafana** (.65) laadt datasource + dashboard automatisch via
  `provisioning/` — staat in deze repo, wijzigingen via git.

## Config wijzigen

`config/` en `provisioning/` liggen op de NAS onder de devin-checkout
(`/volume1/docker/devin/home/workspace/wss-docker/stacks/wss-logs/`).
Wijzigen = aanpassen in git + de betreffende container restarten in
Portainer. Dashboards in de UI bewerken wordt overschreven bij
herprovision — pas het JSON aan via git (of exporteer en commit).

## Fase 2 (later)

15-min lftp-pull van online log-dirs naar `/volume1/docker/wss-logs`
+ extra volume-regel in de devin-stack → actuelere site-logs zonder
de nachtelijke mirror af te wachten. Daarna evt. Prometheus +
Uptime-Kuma-exporter voor metrics.
