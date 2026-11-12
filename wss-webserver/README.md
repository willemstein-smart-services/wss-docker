# wss-webserver — PAC/speeltuin (GHCR image)

`ghcr.io/willemstein-smart-services/wss-webserver:<tag>` — Apache + mod_php (8.4) + MariaDB.
Lokale acceptatie-omgeving die prod (Hetzner) zo dicht mogelijk benadert:
Apache + `.htaccess`, PDO-MySQL, `mail()` (naar catcher, nooit echt versturen).

## IP / bereik
- `192.168.10.64` op `docker_network` → `http://192.168.10.64`
- DB-admin: `http://192.168.10.64/adminer.php` (Adminer)
- MariaDB: `wss-webserver:3306` vanuit andere containers (o.a. devin)

## Volumes
| host | container | inhoud |
|---|---|---|
| `/volume1/docker/webserver/www` | `/var/www/html` | docroot (PAC-site) |
| `/volume1/docker/webserver/mysql` | `/var/lib/mysql` | DB-data (persistent) |
| `/volume1/docker/webserver/initdb` | `/docker-entrypoint-initdb.d` | `.sql`/`.sql.gz` → import bij EERSTE boot |
| `/volume1/docker/webserver/logs` | `/var/log/webstack` | php-error.log + mail.log |
| `/volume1/docker/webserver/cron.d` | `/etc/cron.d` | cronjobs (zelfde regels als wss-devin) |

Tip: je kunt de docroot ook direct op de test_env-checkout wijzen —
`/volume1/docker/devin/home/workspace/www_willemste_in/public_html/test_env`
→ `/var/www/html` — dan is elke Devin-edit meteen zichtbaar.

## Env
| var | default | werking |
|---|---|---|
| `MYSQL_DATABASE` | `wss_pac` | wordt aangemaakt bij eerste boot |
| `MYSQL_USER` / `MYSQL_PASSWORD` | `wss` / `changeme` | user met ALL op die DB, host `%` |
| `MYSQL_ROOT_PASSWORD` | (leeg) | zet root-pw; leeg = socket-auth alleen |

## DB-flow (speeltuin)
1. Lege `mysql`-dir → eerste boot initialiseert + importeert initdb-dumps
2. Nieuw testen = datadir leegmaken + opnieuw booten (of extra DB aanmaken:
   `docker exec wss-webserver mysql -e "CREATE DATABASE x"`)
3. Vanuit devin: `mysql -h wss-webserver -u wss -p<DB_PASS> wss_pac`
   of `bin/usql` / `mysqldump` — bereikbaar via `docker_network`
4. Toekomst "meerdere DBs": site-config kan tegelijk naar lokale
   `wss-webserver:3306` én externe `mi8e.your-database.de:3306` wijzen

## Mail (PAC-veilig)
`sendmail_path` → `mail-catch`: elke `mail()` van de site landt in
`/var/log/webstack/mail.log` — nooit echte mail naar buiten.

## Cron
Zelfde conventie als wss-devin: `/etc/cron.d` is volume, bestandsnamen
zonder punt, `USER`-veld verplicht, env via `/etc/container.env`.

## Release-flow
Zelfde als andere images: bump `org.opencontainers.image.version`, push,
workflow `build-wss-webserver` tagt `latest`+versie+sha.
