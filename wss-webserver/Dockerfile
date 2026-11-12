FROM debian:trixie-slim

LABEL org.opencontainers.image.title="WSS Webserver (PAC)"
LABEL org.opencontainers.image.description="Debian Slim: Apache + mod_php + MariaDB, PAC/speeltuin voor willemste.in"
LABEL org.opencontainers.image.source="https://github.com/willemstein-smart-services/wss-docker"
LABEL org.opencontainers.image.version="1.0"

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Amsterdam

# LAMP + tooling (prod-parity: Apache/mod_php zoals Hetzner)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      apache2 \
      libapache2-mod-php \
      php-cli \
      php-mysql \
      php-curl \
      php-gd \
      php-mbstring \
      php-xml \
      php-zip \
      php-intl \
      php-sqlite3 \
      php-opcache \
      php-apcu \
      mariadb-server \
      mariadb-client \
      composer \
      cron \
      tini \
      curl \
      ca-certificates \
      jq \
      git \
      nano \
      unzip \
      tzdata \
      procps \
      less \
      file && \
    rm -rf /var/lib/apt/lists/* && \
    ln -sf "/usr/share/zoneinfo/${TZ}" /etc/localtime && \
    echo "${TZ}" > /etc/timezone

# Apache: eigen vhost, rewrite+headers, logs -> docker logs
COPY apache-site.conf /etc/apache2/sites-available/000-wss.conf
RUN a2dissite 000-default && \
    a2ensite 000-wss && \
    a2enmod rewrite headers && \
    echo "ServerName wss-webserver" > /etc/apache2/conf-available/servername.conf && \
    a2enconf servername && \
    ln -sf /proc/self/fd/1 /var/log/apache2/access.log && \
    ln -sf /proc/self/fd/2 /var/log/apache2/error.log

# MariaDB: bereikbaar voor andere containers (devin) + utf8mb4
RUN printf '[mysqld]\nbind-address=0.0.0.0\ncharacter-set-server=utf8mb4\ncollation-server=utf8mb4_unicode_ci\nskip-name-resolve\n' \
      > /etc/mysql/mariadb.conf.d/99-wss.cnf

# PHP PAC-instellingen (apache2 + cli) + sendmail-catcher
COPY php-pac.ini /tmp/php-pac.ini
RUN for d in /etc/php/*/apache2/conf.d /etc/php/*/cli/conf.d; do \
      cp /tmp/php-pac.ini "$d/99-wss-pac.ini"; \
    done
COPY mail-catch /usr/local/bin/mail-catch
RUN chmod 755 /usr/local/bin/mail-catch

# Adminer (single-file DB-admin) -> /adminer.php via Alias in vhost
RUN mkdir -p /opt/adminer && \
    curl -fL --retry 3 \
      "https://github.com/vrana/adminer/releases/download/v4.8.1/adminer-4.8.1.php" \
      -o /opt/adminer/adminer.php

COPY entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh

EXPOSE 80 3306

ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
