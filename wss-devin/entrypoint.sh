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

# --- 2) env voor cronjobs ------------------------------------------------
# cronjobs krijgen container-env NIET mee; jobs doen `. /etc/container.env`
# of zetten VAR=value-regels bovenin hun cron.d-bestand.
printenv | grep -vE '^(PWD|OLDPWD|SHLVL|_)=' > /etc/container.env
chmod 0644 /etc/container.env
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
  exec runuser -u devin -- "$@" /bin/bash -l
fi

echo "=== WSS DEVIN RUNNING ($*) ==="
exec "$@"
