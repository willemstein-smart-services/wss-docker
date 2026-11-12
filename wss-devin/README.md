# wss-devin — GHCR image

`ghcr.io/willemstein-smart-services/wss-devin:<tag>` — Debian trixie-slim dev-container met ttyd-webterminal, cron en tooling.

## Nieuw in 1.2
- **cron** (Debian) met `/etc/cron.d` als volume — zie hieronder
- **entrypoint + tini** als PID 1 (signal handling, geen zombies)
- **tmux**, **netwerk-tools** (ping/dig/traceroute/ip/netstat)
- **CLI QoL**: ripgrep, fd, fzf, bat, bash-completion, **gh** CLI
- **Dev-bundel**: python3-pip/-venv + pipx, lftp, ksh, sudo (devin NOPASSWD)
- **Dotfiles-persistentie** vanuit het workspace-volume

## Cron — volume `/etc/cron.d`
Host-dir mounten op `/etc/cron.d`; cron scant die **elke minuut opnieuw**,
dus edits op de NAS zijn direct actief én overleven redeploys.

Regels (cron weigert/ignoreert anders):
- Bestandsnaam **zonder punt**: `wss-intake` werkt, `wss-intake.cron` niet
- Systeem-formaat, 6e veld = user:
  ```
  */15 * * * * devin /home/devin/workspace/bin/intake_poller.sh >> /var/log/wss/intake.log 2>&1
  ```
- Perms worden bij boot gefixt (root:root 0644) — hoef je op NAS niet te regelen
- Container-env is NIET zichtbaar in jobs: gebruik `. /etc/container.env`
  in je script, of `VAR=value`-regels bovenin het cron.d-bestand
- Geen syslog: redirect output naar `/var/log/wss/` (logs-volume) —
  `MAILTO=""` bovenin voorkomt mail-pogingen
- Gebruik ALLEEN `/etc/cron.d`: `/etc/cron.hourly|daily|weekly` leven in
  de image en zijn dus NIET persistent

## Dotfiles — `workspace/.devin/dotfiles/`
Alles daarin wordt bij boot in `~devin` gelinkt (echte dot-namen gebruiken):
`.bashrc`, `.profile`, `.gitconfig`, `.tmux.conf`, `.vimrc`, `.local`, …
- dir `ssh/` → `~/.ssh`, perms worden gefixt (700 dir / 600 keys)
- `bash_history` wordt via HISTFILE direct naar dit dir geschreven
- tip: `.local` erin → `~/.local/bin/devin` (CLI) overleeft ook redeploys

## Compose
```yaml
wss-devin:
  image: ghcr.io/willemstein-smart-services/wss-devin:1.2
  container_name: wss-devin
  hostname: wss-devin
  restart: unless-stopped
  environment:
    TZ: Europe/Amsterdam
    # DEVIN_WEB_PASSWORD: "STERK_WACHTWOORD"   # -> ttyd credential devin:<pw>
  volumes:
    - /volume1/docker/wss_devin/workspace:/home/devin/workspace
    - /volume1/docker/wss_devin/cron.d:/etc/cron.d
    - /volume1/docker/wss_devin/logs:/var/log/wss
  stdin_open: true
  tty: true
```
Geen `command:` nodig — entrypoint start ttyd als devin op :7681
(eigen `command:` blijft werken, backwards compatible).

## Release-flow
1. Wijzig `Dockerfile`/`entrypoint.sh`, bump `org.opencontainers.image.version`
2. Push → workflow `build-wss-devin` bouwt en tagt:
   `latest` + Dockerfile-versie (`1.2`) + `sha-xxxx`
3. Handmatig extra tag: Actions → build-wss-devin → tag invoeren
4. NAS: `docker pull ghcr.io/willemstein-smart-services/wss-devin:1.2`
   (bestaande ghcr.io-login blijft werken; package staat private)
