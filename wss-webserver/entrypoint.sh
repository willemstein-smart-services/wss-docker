#!/bin/bash
# wss-webserver 1.0 — entrypoint
#  1) cron.d-volume perms + env dump + cron starten
#  2) MariaDB bootstrap bij lege datadir (+ .sql import uit initdb-dir)
#  3) mariadbd + apache starten, nette shutdown via trap
set -e
echo "=== WSS WEBSERVER STARTUP ==="

mkdir -p /run/mysqld /var/log/webstack
chown mysql:mysql /run/mysqld

# --- 1) cron + env (zelfde patroon als wss-devin) -------------------------
if [ -d /etc/cron.d ]; then
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
printenv | grep -vE '^(PWD|OLDPWD|SHLVL|_)=' > /etc/container.env
chmod 0644 /etc/container.env
cron || echo "LET OP: cron start mislukt - web gaat gewoon door"

# --- 2) MariaDB bootstrap --------------------------------------------------
chown -R mysql:mysql /var/lib/mysql 2>/dev/null || true
DB="${MYSQL_DATABASE:-wss_pac}"
DB_USER="${MYSQL_USER:-wss}"
DB_PASS="${MYSQL_PASSWORD:-changeme}"
ROOTPW_ARG=""
[ -n "${MYSQL_ROOT_PASSWORD:-}" ] && ROOTPW_ARG="-p${MYSQL_ROOT_PASSWORD}"

if [ ! -d /var/lib/mysql/mysql ]; then
  echo "Eerste boot: MariaDB initialiseren..."
  mariadb-install-db --user=mysql --datadir=/var/lib/mysql \
      --auth-root-authentication-method=socket > /dev/null
  mysqld_safe --skip-networking &
  for _ in $(seq 30); do
    mysqladmin ping > /dev/null 2>&1 && break
    sleep 1
  done
  mysql -uroot <<SQL
CREATE DATABASE IF NOT EXISTS \`$DB\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`$DB\`.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
SQL
  if [ -n "${MYSQL_ROOT_PASSWORD:-}" ]; then
    mysql -uroot -e "ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('${MYSQL_ROOT_PASSWORD}');"
  fi
  for f in /docker-entrypoint-initdb.d/*.sql /docker-entrypoint-initdb.d/*.sql.gz; do
    [ -f "$f" ] || continue
    echo "importeer $(basename "$f") -> $DB"
    case "$f" in
      *.gz) zcat "$f" | mysql -uroot "$DB" ;;
      *)    mysql -uroot "$DB" < "$f" ;;
    esac
  done
  mysqladmin -uroot ${ROOTPW_ARG} shutdown 2>/dev/null || true
  sleep 2
fi

# --- 3) start --------------------------------------------------------------
echo "MariaDB starten (:3306, bind 0.0.0.0, db=${DB})..."
runuser -u mysql -- /usr/sbin/mariadbd &
MYSQL_PID=$!

echo "Apache starten (:80)..."
apache2ctl -D FOREGROUND &
APACHE_PID=$!

trap 'apache2ctl stop 2>/dev/null || kill $APACHE_PID 2>/dev/null; mysqladmin -uroot ${ROOTPW_ARG} shutdown 2>/dev/null || kill $MYSQL_PID 2>/dev/null; wait || true' TERM INT
echo "=== WSS WEBSERVER RUNNING ==="
wait -n $MYSQL_PID $APACHE_PID
exit 1
