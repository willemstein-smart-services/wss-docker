#!/usr/bin/env bash
# loki_event LEVEL SRC EVENT [bericht] — push één gestructureerde regel
# naar Loki als job=wss-cron met echte severity als stream-label.
#
#   bin/loki_event.sh err  backup BACKUP_FAILED "mirror /htdocs rc=1"
#   bin/loki_event.sh info backup BACKUP_OK
#
# De regeltekst begint met het volledige severity-woord (error/warning/...)
# zodat dashboards die op tekst filteren het event óók vangen.
set -uo pipefail

LEVEL="${1:?level: err|warn|notice|info|debug|crit|alert}"
SRC="${2:?src: backup|logpull|noise-review|...}"
EVENT="${3:?EVENT_NAAM}"
MSG="${4:-}"
LOKI="${LOKI_URL:-http://wss-loki:3100}"

case "$LEVEL" in
  err)   WORD=error ;;
  warn)  WORD=warning ;;
  crit)  WORD=critical ;;
  *)     WORD="$LEVEL" ;;
esac

python3 - "$LEVEL" "$SRC" "$EVENT" "$WORD $EVENT $MSG" "$LOKI" <<'PY'
import json, sys, time, urllib.request
level, src, event, line, loki = sys.argv[1:6]
payload = {"streams": [{"stream": {"job": "wss-cron", "level": level,
           "src": src, "event": event},
           "values": [[str(time.time_ns()), line]]}]}
req = urllib.request.Request(loki + "/loki/api/v1/push",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"})
try:
    urllib.request.urlopen(req, timeout=10)
except Exception as e:
    print(f"loki_event: push mislukt: {e}", file=sys.stderr)
PY
