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
