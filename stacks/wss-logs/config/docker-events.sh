#!/bin/sh
# docker-events -> Loki forwarder (sidecar, docker:cli image)
# Streamt daemon-events (create/start/die/pull/...) als job=docker-events.
# Draait op busybox-sh; socket is :ro-gemount.
LOKI="${LOKI_URL:-http://192.168.10.66:3100}/loki/api/v1/push"

while :; do
  docker events --format '{{json .}}' 2>/dev/null | while IFS= read -r line; do
    ts=$(date +%s%N)
    esc=$(printf '%s' "$line" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
    printf '{"streams":[{"stream":{"job":"docker-events","level":"info"},"values":[["%s","%s"]]}]}' "$ts" "$esc" \
      | wget -q -T 10 -O /dev/null --post-data=@- --header='Content-Type: application/json' "$LOKI"
  done
  echo "$(date -Iseconds) docker-events: stream onderbroken, retry in 5s" >&2
  sleep 5
done
