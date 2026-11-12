FROM debian:trixie-slim

LABEL org.opencontainers.image.title="WSS Monitoring"
LABEL org.opencontainers.image.description="Debian Slim: Uptime Kuma + ttyd webterminal"
LABEL org.opencontainers.image.source="https://github.com/willemstein-smart-services/wss-docker"
LABEL org.opencontainers.image.version="1.0"

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Amsterdam

# Alle runtime-packages op build-time (was: elke boot opnieuw)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      bash curl ca-certificates git \
      openssh-client tzdata procps less \
      passwd util-linux nodejs npm \
      iputils-ping dnsutils && \
    rm -rf /var/lib/apt/lists/*

# ttyd webterminal
RUN set -eux; \
    ARCH="$(uname -m)"; \
    case "$ARCH" in \
      x86_64) TTYD_ARCH="x86_64" ;; \
      aarch64) TTYD_ARCH="aarch64" ;; \
      armv7l) TTYD_ARCH="armhf" ;; \
      *) echo "Unsupported architecture: $ARCH"; exit 1 ;; \
    esac; \
    curl -fL --retry 3 \
      "https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.${TTYD_ARCH}" \
      -o /usr/local/bin/ttyd; \
    chmod 755 /usr/local/bin/ttyd

# monitor user (uid 1001, geen home nodig: volume overmount)
RUN useradd -M -s /bin/bash -u 1001 monitor && \
    mkdir -p /home/monitor/workspace /opt && \
    chown -R monitor:monitor /home/monitor

# Voorgebakken Uptime Kuma: npm setup op build-time ->
# eerste boot = alleen kopieren naar volume i.p.v. minuten npm install
# Let op: chown VOOR npm run setup, anders faalt git met
# "dubious ownership" (exit 128) onder user monitor.
# Build-tools (python3/make/g++) alleen nodig voor native npm-modules
# (sqlite3 e.a.) -> in deze layer installeren EN weer weggooien.
# Let op: VOLLEDIGE clone (geen --depth) — npm run setup van Kuma
# gebruikt git-tags/describe voor versiebepaling; die ontbreken shallow.
RUN git clone https://github.com/louislam/uptime-kuma.git /opt/uptime-kuma && \
    chown -R monitor:monitor /opt/uptime-kuma

RUN apt-get update && \
    apt-get install -y --no-install-recommends python3 make g++ && \
    rm -rf /var/lib/apt/lists/*

RUN runuser -u monitor -- env HOME=/home/monitor \
      bash -c 'cd /opt/uptime-kuma && npm run setup && touch .wss-installed'

RUN apt-get purge -y python3 make g++ && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh

EXPOSE 3001 7681

ENTRYPOINT ["/entrypoint.sh"]
