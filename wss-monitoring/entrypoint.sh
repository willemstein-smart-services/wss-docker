#!/bin/bash
set -e
echo "=== WSS MONITORING STARTUP ==="

# Volume kan leeg/verkeerde eigenaar zijn
mkdir -p /home/monitor/workspace
chown -R monitor:monitor /home/monitor 2>/dev/null || true

echo "Checking Uptime Kuma installation..."
if [ ! -d /home/monitor/uptime-kuma/.git ]; then
  if [ -d /opt/uptime-kuma/.git ]; then
    echo "Eerste boot: voorgebakken Kuma naar volume kopieren..."
    rm -rf /home/monitor/uptime-kuma
    cp -a /opt/uptime-kuma /home/monitor/uptime-kuma
    chown -R monitor:monitor /home/monitor/uptime-kuma
  else
    echo "Cloning full Uptime Kuma repository..."
    rm -rf /home/monitor/uptime-kuma
    runuser -u monitor -- \
      git clone https://github.com/louislam/uptime-kuma.git /home/monitor/uptime-kuma
  fi
fi

if [ ! -f /home/monitor/uptime-kuma/.wss-installed ]; then
  echo "Installing Uptime Kuma dependencies..."
  runuser -u monitor -- env HOME=/home/monitor \
    bash -c 'cd /home/monitor/uptime-kuma && npm run setup && touch .wss-installed'
else
  echo "Uptime Kuma is already installed."
fi

echo "Fetching tags (non-fatal)..."
runuser -u monitor -- \
  bash -c 'cd /home/monitor/uptime-kuma && git fetch --tags --force' || true

echo "Starting Uptime Kuma on port 3001..."
runuser -u monitor -- env HOME=/home/monitor \
  bash -c 'cd /home/monitor/uptime-kuma && exec node server/server.js' &
KUMA_PID=$!

echo "Starting webterminal on port 7681..."
runuser -u monitor -- \
  /usr/local/bin/ttyd \
  --writable \
  --check-origin \
  --credential "monitor:${MONITOR_WEB_PASSWORD}" \
  --port 7681 \
  --cwd /home/monitor/workspace \
  /bin/bash -l &
TTYD_PID=$!

trap 'kill $KUMA_PID $TTYD_PID 2>/dev/null || true; wait || true' TERM INT
echo "=== WSS MONITORING RUNNING ==="
wait -n $KUMA_PID $TTYD_PID
exit 1
