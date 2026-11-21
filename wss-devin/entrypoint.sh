#!/bin/bash
# wss-devin 1.2 — entrypoint
#  1) cron.d-volume: perms fixen + cron starten
#  2) container-env dumpen voor cronjobs -> /etc/container.env
#  3) dotfiles bootstrap vanuit workspace-volume
#  4) exec CMD (default: ttyd webterminal als devin)
set -e
echo "=== WSS DEVIN STARTUP ==="

WS=/home/devin/workspace
DOTDIR="$WS/.devin/dotfiles"

# --- 1) cron -------------------------------------------------------------
# /etc/cron.d is een volume (NAS: .../wss_devin/cron.d). Cron eist:
# root-owned, niet group/world-writable, GEEN punt/tilde in de bestandsnaam.
if [ -d /etc/cron.d ]; then
  # dir zelf ook: cron negeert cron.d als hij group/world-writable of niet root-owned is
  chown root:root /etc/cron.d 2>/dev/null || true
  chmod 0755 /etc/cron.d 2>/dev/null || true
  for f in /etc/cron.d/*; do
    [ -f "$f" ] || continue
    case "$(basename "$f")" in
      *.*|*~|*\#*)
        echo "LET OP: '$(basename "$f")' wordt door cron genegeerd (punt/tilde/# in naam)" ;;
      *)
        chown root:root "$f" 2>/dev/null || true
        chmod 0644 "$f" ;;
    esac
  done
fi

# --- 1b) recreate-proof cronjobs -----------------------------------------
# Deze jobs staan NIET in de user-crontab (die leeft in container-fs en
# overleeft geen recreate). Entrypoint installeert ze idempotent in het
# cron.d-volume — na elke (re)deploy staan ze er vanzelf weer.
for job in wss-cronbeat wss-portainer-audit wss-devin-selfcheck; do
  [ -f "/etc/cron.d/$job" ] && continue
  case "$job" in
    wss-cronbeat)
      line='* * * * * devin /home/devin/workspace/bin/wss_cronbeat.sh >> /var/log/wss/cronbeat.log 2>&1'
      need=/home/devin/workspace/bin/wss_cronbeat.sh ;;
    wss-portainer-audit)
      line='*/5 * * * * devin /home/devin/workspace/bin/wss_portainer_audit.sh >> /var/log/wss/portainer-audit.log 2>&1'
      need=/home/devin/workspace/bin/wss_portainer_audit.sh ;;
    wss-devin-selfcheck)
      # image-pad (geen workspace-afhankelijkheid -> werkt ook in klant-container)
      line='41 * * * * devin /usr/local/lib/wss/bin/wss_devin_selfcheck.sh >> /var/log/wss/devin-selfcheck.log 2>&1'
      need=/usr/local/lib/wss/bin/wss_devin_selfcheck.sh ;;
  esac
  # workspace-scripts ontbreken in bv. de klant-container -> job overslaan
  # i.p.v. elke cron-run 'not found' te loggen
  [ -f "$need" ] || { echo "cron.d: $job overgeslagen ($need ontbreekt)"; continue; }
  printf 'MAILTO=""\n%s\n' "$line" > "/etc/cron.d/$job"
  chown root:root "/etc/cron.d/$job" 2>/dev/null || true
  chmod 0644 "/etc/cron.d/$job"
  echo "cron.d: $job geinstalleerd (recreate-proof)"
done

# --- 2) env voor cronjobs ------------------------------------------------
# cronjobs krijgen container-env NIET mee; jobs doen `. /etc/container.env`
# of zetten VAR=value-regels bovenin hun cron.d-bestand.
printenv | grep -vE '^(PWD|OLDPWD|SHLVL|_)=' > /etc/container.env
chmod 0644 /etc/container.env

# --- 2b) devin-PATH voor alle shells ---------------------------------------
# /etc/profile reset PATH (mist ~/.local/bin) en een VERSE home-volume heeft
# geen .profile met de export -> 'devin: command not found' in ttyd/cron.
# Container-fs files: bij elke start wegschrijven = redeploy-proof, werkt in
# elke container van dit image (ook de klant-container met leeg volume).
printf 'export PATH="$HOME/.local/bin:$PATH"\n' > /etc/profile.d/devin-path.sh
chmod 644 /etc/profile.d/devin-path.sh
grep -q 'local/bin' /etc/bash.bashrc || \
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> /etc/bash.bashrc
mkdir -p /var/log/wss

if cron; then
  echo "cron actief - /etc/cron.d wordt elke minuut opnieuw gescand"
else
  echo "LET OP: cron start mislukt - ttyd gaat gewoon door"
fi

# --- 3) dotfiles ---------------------------------------------------------
# Alles in $DOTDIR (volume!) wordt in ~devin gelinkt -> overleeft redeploy.
# Namen = echte dot-namen: .bashrc .profile .gitconfig .tmux.conf .vimrc
# .local (devin CLI!)  |  dir 'ssh/' -> ~/.ssh met gefixte perms (700/600).
mkdir -p "$DOTDIR"
for item in "$DOTDIR"/.[!.]* "$DOTDIR"/*; do
  [ -e "$item" ] || continue
  name="$(basename "$item")"
  [ "$name" = "ssh" ] && continue
  ln -sfn "$item" "/home/devin/$name"
done
if [ -d "$DOTDIR/ssh" ]; then
  chmod 700 "$DOTDIR/ssh"
  chown -R devin:devin "$DOTDIR/ssh" 2>/dev/null || true
  find "$DOTDIR/ssh" -type f ! -name '*.pub' -exec chmod 600 {} +
  find "$DOTDIR/ssh" -type f -name '*.pub' -exec chmod 644 {} +
  if [ -e /home/devin/.ssh ] && [ ! -L /home/devin/.ssh ]; then
    echo "LET OP: /home/devin/.ssh is een echte dir -> volume-ssh niet gelinkt"
  else
    ln -sfn "$DOTDIR/ssh" /home/devin/.ssh
  fi
fi

# --- 4) CMD --------------------------------------------------------------
# Geen args (of kale 'ttyd') -> default webterminal als devin op :7681.
# DEVIN_WEB_PASSWORD gezet -> credential + origin-check erbij.
if [ $# -eq 0 ] || { [ $# -eq 1 ] && [ "$1" = "ttyd" ]; }; then
  set -- /usr/local/bin/ttyd --writable --port 7681 --cwd "$WS"
  [ -n "${DEVIN_WEB_PASSWORD:-}" ] && \
    set -- "$@" --check-origin --credential "devin:${DEVIN_WEB_PASSWORD}"
  # xterm.js theming per container (bv. groen 'robot' voor klant-zone):
  #   TTYD_THEME='{"background":"#000000","foreground":"#00ff41"}'
  #   TTYD_TITLE='DEVIN-KLANT'  (fixed tabtitel)
  [ -n "${TTYD_THEME:-}" ] && set -- "$@" -t "theme=${TTYD_THEME}"
  [ -n "${TTYD_TITLE:-}" ] && set -- "$@" -t "titleFixed=${TTYD_TITLE}"
  exec runuser -u devin -- "$@" /bin/bash -l
fi

echo "=== WSS DEVIN RUNNING ($*) ==="
exec "$@"
