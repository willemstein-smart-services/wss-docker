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

- **Alloy** (.67) verzamelt: docker-logs via `docker.sock` (ALLE
  containers op de NAS), `/var/log/wss/*.log` en de mail-catcher.
- **Site-app logs** (`{job="site-app", env="test|prod"}`) komen via
  `wss_log_pull.sh` in de devin-container: elke 15 min read-only
  SFTP-download van `log/logging.php`, alleen nieuwe regels worden
  direct naar Loki's push-API gestuurd (met originele timestamps).
- **Loki** (.66) bewaart 90 dagen op `/volume1/docker/wss-grafana/loki`.
- **Grafana** (.65) laadt datasource + dashboard automatisch via
  `provisioning/` — staat in deze repo, wijzigingen via git.

## Config wijzigen

`config/` en `provisioning/` liggen op de NAS onder de devin-checkout
(`/volume1/docker/devin/home/workspace/wss-docker/stacks/wss-logs/`).
Wijzigen = aanpassen in git + de betreffende container restarten in
Portainer. Dashboards in de UI bewerken wordt overschreven bij
herprovision — pas het JSON aan via git (of exporteer en commit).

## Fase 2 (gedaan)

`wss_log_pull.sh` (devin-cron `wss-logs-pull`, `*/15 * * * *`):
lftp `get` van `test_env/log/logging.php` + `full_site/log/logging.php`
-> `bin/loki_push_log.py` pusht alleen nieuwe regels naar Loki
(state in `workspace/.devin/state/logpull-*.pos`). Geen volumes of
redeploys nodig; `reject_old_samples_max_age` in loki-config staat
op 90d zodat historische regels ook binnenkunnen.

## Later (fase 3, metrics)

Evt. Prometheus/VictoriaMetrics + Uptime-Kuma-exporter, Synology
SNMP, MariaDB-exporter -> Grafana-dashboards met metrics naast logs.
