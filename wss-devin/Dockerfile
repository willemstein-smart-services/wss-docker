FROM debian:trixie-slim

LABEL org.opencontainers.image.title="WSS Devin Linux"
LABEL org.opencontainers.image.description="Debian Slim: dev-tools, ttyd webterminal, cron"
LABEL org.opencontainers.image.source="https://github.com/willemstein-smart-services/wss-docker"
LABEL org.opencontainers.image.version="1.2"

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Amsterdam

# Install Linux tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      bash \
      bash-completion \
      curl \
      ca-certificates \
      git \
      openssh-client \
      tzdata \
      procps \
      less \
      passwd \
      util-linux \
      php-cli \
      python3 \
      python3-pip \
      python3-venv \
      pipx \
      jq \
      sqlite3 \
      default-mysql-client \
      netcat-openbsd \
      vim-tiny \
      nano \
      tree \
      file \
      unzip \
      htop \
      rsync \
      libio-socket-ssl-perl \
      cron \
      tini \
      sudo \
      tmux \
      lftp \
      ksh \
      iputils-ping \
      dnsutils \
      traceroute \
      iproute2 \
      net-tools \
      ripgrep \
      fd-find \
      fzf \
      bat && \
    rm -rf /var/lib/apt/lists/*

# Debian noemt de binaries batcat/fdfind -> verwachte namen linken
RUN ln -sf /usr/bin/batcat /usr/local/bin/bat && \
    ln -sf /usr/bin/fdfind /usr/local/bin/fd

# Install ttyd webterminal
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

# Install gh CLI (zelfde multi-arch patroon als ttyd)
RUN set -eux; \
    ARCH="$(uname -m)"; \
    case "$ARCH" in \
      x86_64) GH_ARCH="amd64" ;; \
      aarch64) GH_ARCH="arm64" ;; \
      armv7l) GH_ARCH="armv6" ;; \
      *) echo "Unsupported architecture: $ARCH"; exit 1 ;; \
    esac; \
    curl -fL --retry 3 \
      "https://github.com/cli/cli/releases/download/v2.103.3/gh_2.103.3_linux_${GH_ARCH}.tar.gz" \
      -o /tmp/gh.tgz; \
    tar -xzf /tmp/gh.tgz -C /tmp; \
    install -m755 "/tmp/gh_2.103.3_linux_${GH_ARCH}/bin/gh" /usr/local/bin/gh; \
    rm -rf /tmp/gh.tgz "/tmp/gh_2.103.3_linux_${GH_ARCH}"

# Create Devin user, matching existing UID (+ NOPASSWD sudo, container-local)
RUN useradd -m -u 1000 -s /bin/bash devin && \
    mkdir -p /home/devin/workspace \
             /home/devin/.local/bin && \
    chown -R devin:devin /home/devin && \
    echo 'devin ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/devin && \
    chmod 440 /etc/sudoers.d/devin

# Bash-history naar het workspace-volume + git safe.directory voor volume-repos
# (/etc/bash.bashrc dekt login én non-login interactive shells, o.a. tmux)
RUN printf '%s\n' \
      'export HISTFILE=/home/devin/workspace/.devin/dotfiles/bash_history' \
      'export HISTSIZE=10000' \
      'export HISTFILESIZE=20000' \
      'export HISTCONTROL=ignoredups' \
      >> /etc/bash.bashrc && \
    git config --system --add safe.directory '*'

# Make Devin CLI available in all terminal sessions
ENV PATH="/home/devin/.local/bin:${PATH}"

WORKDIR /home/devin/workspace

COPY entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh

EXPOSE 7681

ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
