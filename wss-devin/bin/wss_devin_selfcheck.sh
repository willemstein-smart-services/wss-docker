#!/usr/bin/env bash
# wss_devin_selfcheck.sh — periodieke gezondheidscheck van de Devin CLI
# zelf: vangt het "fail-stopped" scenario (usage cap / quota / auth stuk)
# waarbij automation zoals noise-review stilletjes stopt.
#
# Cron: 1x/uur. Pusht resultaat naar Loki als
#   {job="wss-cron", src="devin-selfcheck", event=DEVIN_SELFCHECK_*}
# -> crit-events landen in de wss-cron error feed + wss-devin-selfcheck
#    Grafana-alert (provisioning/alerting/wss-devin-selfcheck.yaml).
#
# Checks (kortstondig, fail-fast):
#   1) devin auth status        — token/login geldig?
#   2) devin cloud drs whoami   — api.devin.ai bereikbaar + API-key (gratis probe)
#   3) live probe `devin -p`    — échte mini-sessie; enige check die
#      quota/usage-limit/model-blokkade daadwerkelijk uitoefent.
#
# Hostname gaat mee in de msg -> zelfde script herbruikbaar in een tweede
# (klant) container; alerts/feed tonen dan welke container faalt.
#
# Image-canonical: deze file -> /usr/local/lib/wss/bin/ in het image
# (loki_event.sh wordt via de eigen script-dir gevonden; geen
# workspace-afhankelijkheid -> werkt ook in de klant-container).
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EVT() { "$SELF_DIR/loki_event.sh" "$1" devin-selfcheck "$2" "$3" >/dev/null 2>&1 || true; }
HOST="$(hostname)"
PROBE_DIR=/tmp/devin-selfcheck
PROBE_TIMEOUT=300

# geen overlap als een probe langer dan een uur hangt
exec 9> /tmp/wss_devin_selfcheck.lock
flock -n 9 || exit 0

# --- 1) auth ---------------------------------------------------------------
AUTH_OUT="$(timeout 30 devin auth status 2>&1)"
if ! grep -qi 'logged in' <<<"$AUTH_OUT"; then
    EVT crit DEVIN_SELFCHECK_FAIL "$HOST auth: $(tail -1 <<<"$AUTH_OUT" | tr '\n' ' ' | cut -c1-140)"
    exit 1
fi

# --- 2) API-reachability + api-key (gratis, geen sessie) ---------------------
API_OUT="$(timeout 30 devin cloud drs whoami 2>&1)"
if [ $? -ne 0 ] || ! grep -q '"api_key_set": *true' <<<"$API_OUT"; then
    EVT crit DEVIN_SELFCHECK_FAIL "$HOST api: $(tail -1 <<<"$API_OUT" | tr '\n' ' ' | cut -c1-140)"
    exit 1
fi

# --- 3) live probe: echte mini-sessie (vangt quota/limit/model-blok) ---------
mkdir -p "$PROBE_DIR"
cd "$PROBE_DIR" || exit 1
PROBE_OUT="$(timeout "$PROBE_TIMEOUT" devin -p --respect-workspace-trust false \
    -- 'Reply with exactly this token and nothing else: SELFCHECK_OK' 2>&1)"
rc=$?

if [ $rc -ne 0 ] || ! grep -q 'SELFCHECK_OK' <<<"$PROBE_OUT"; then
    tail1="$(tail -3 <<<"$PROBE_OUT" | tr '\n' ' ' | tr -s ' ' | cut -c1-140)"
    if [ $rc -eq 124 ]; then
        EVT crit DEVIN_SELFCHECK_FAIL "$HOST probe: timeout na ${PROBE_TIMEOUT}s"
    elif grep -qiE 'usage limit|quota|billing|payment|insufficient|credits|429|rate.?limit' <<<"$PROBE_OUT"; then
        EVT crit DEVIN_QUOTA_FAIL "$HOST probe: $tail1"
    else
        EVT crit DEVIN_SELFCHECK_FAIL "$HOST probe rc=$rc: $tail1"
    fi
    exit 1
fi

EVT info DEVIN_SELFCHECK_OK "$HOST auth+api+probe ok"
exit 0
