# wss-docker — WSS container-images

Alle WSS Docker-images op één plek. Builds pushen naar de
org-GHCR: `ghcr.io/willemstein-smart-services/<image>:<tag>` via
`GITHUB_TOKEN` — geen PAT/secret nodig.

## Layout
| dir | image |
|---|---|
| `wss-devin/` | dev-container: ttyd, cron, tooling |
| `wss-monitoring/` | Uptime Kuma + ttyd |
| `wss-webserver/` | Apache + mod_php + MariaDB (PAC) |
| `.github/workflows/build-<image>.yml` | per-image build & push |
| `stacks/wss/docker-compose.yml` | Portainer-stack (devin+flows+monitoring) |
| `stacks/wss-devin-klant/docker-compose.yml` | losse stack: Devin CLI voor klant-werk (trust-zone gescheiden van interne `devin`) |
| `wss-devin/bin/` | scripts IN het image (`/usr/local/lib/wss/bin/`): loki_event, devin-selfcheck |

## Release-flow (per image)
1. Wijzig files in `<image>/`, bump `org.opencontainers.image.version` in de Dockerfile
2. Push → workflow `build-<image>` bouwt en tagt automatisch:
   - `latest`
   - Dockerfile-versie (`1.2`)
   - `sha-xxxx`
3. Extra tag: Actions → build-\<image\> → Run workflow → tag invoeren
4. NAS/Portainer: `image: ghcr.io/willemstein-smart-services/<image>:<tag>`

## Nieuwe image toevoegen
1. Nieuwe dir `<image>/` met `Dockerfile` (+ `entrypoint.sh`, `.dockerignore`)
   en `org.opencontainers.image.version`-label
2. Kopieer een `build-*.yml`, vervang `<image>`-naam en `paths:`/`context:`
3. Push → eerste build maakt het GHCR-package aan (org, private)

## Pullen op de NAS
```bash
docker login ghcr.io -u <user> -p <PAT read:packages>   # eenmalig
docker pull ghcr.io/willemstein-smart-services/wss-devin:1.2
```
Packages zijn private; zet eventueel op public via package → settings.

## Tag-beleid
- Elke build tagt `latest` + Dockerfile-versie + `sha-xxxx` (mutable tags)
- Stack gebruikt `:latest` + `pull_policy: always` -> redeploy = nieuwste build
- Wil je pinnen/rollback: zet `image: ...:<versie>` + `pull_policy: missing`

## Stacks deployen (Portainer = git-source)

ALLE stacks in Portainer zijn **git-repository stacks**: ze wijzen naar
deze repo + het compose-pad. Deployen = **Pull and redeploy** in Portainer
— die haalt de laatste commit. Nooit compose-inhoud handmatig plakken.

Secrets horen NIET in compose en niet in Portainer-velden:
- `.devin/*.env` files op het NAS-volume (bijv. `grafana.env` met
  `TELEGRAM_BOT_TOKEN`, perms 604) → :ro-volume in de service mounten →
  in de entrypoint sourcen: `entrypoint: ["sh","-c","set -a; . /pad; set +a; exec /run.sh"]`
- **`env_file:` werkt NIET** onder Portainer (resolve client-side in de
  portainer-container waar /volume1 niet bestaat). Volumes resolven
  wél daemon-side op de NAS.
- Let op container-uid: grafana draait als uid 472 — een `600`-envfile
  is dan onleesbaar (vandaar 604: owner-only write, world read).

## Twee Devin-zones: devin (intern) vs wss-devin-klant

Twee Devin-containers, twee trust-zones, zelfde `wss-devin`-image:

| | `devin` (AdminDevin) | `wss-devin-klant` (DevinKlant) |
|---|---|---|
| Stack | `stacks/wss/` | `stacks/wss-devin-klant/` |
| IP | 192.168.10.61 | 192.168.10.70 |
| Home-volume | `/volume1/docker/devin/home` | `/volume1/docker/devin-klant/home` |
| Toegang | interne creds, mounts, monitoring | ALLEEN klant-creds — geen interne mounts |

**CLI-seed**: de Devin CLI leeft op het home-volume, niet in het image.
Bij een verse container alleen `.local/bin` + `.local/share/devin/cli/_versions`
kopiëren — nooit de rest van `cli/` (dat lekt sessie-history) en nooit
`credentials.toml`/`~/.config` (dat lekt credentials).

**Handover** (concept geaccepteerd -> DevinKlant):
- AdminDevin schrijft bundles naar `/handover/<slug>/` =
  `/volume1/docker/devin-klant/home/workspace/handover/<slug>/` —
  dezelfde map als `~/workspace/handover/` bij DevinKlant (geen stack-wijziging
  aan klant-zijde; één extra bind in `stacks/wss/`).
- Bundle: `handover.json` + `secrets.env` + `READY` (+ opt. `concept.tar.gz`).
  Script: `bin/wss_klant_handover.sh` (workspace-repo), cron `:47/u --auto`.
- DevinKlant verwerkt per zijn `klant-deploy.md` rule -> `klanten/<slug>/`.

**Klant deploy-lock**: SFTP-deploys + DB-mutaties naar klanten vereisen
`UNLOCKED` op `klant:<customer_details.id>` of `ALL` (willemste.in
`klant-deploy-lock.php` + `admin_klant_deploy_2fa.php`). DevinKlant mag
alleen deployen via `klant_deploy.sh` — de check zit IN het script.
