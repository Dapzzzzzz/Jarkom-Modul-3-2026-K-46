#!/bin/sh
# Soal 14
#   - maki: frontend Nginx/PHP-FPM, hostname, hanya menerima gojo.
#   - File repo: perquest-scripts/soal_14/maki.sh
[ "$(hostname | tr '[:upper:]' '[:lower:]')" = maki ] || { echo "Hanya untuk node maki" >&2; exit 1; }

set -eu
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
fail() { echo "FAIL: $*" >&2; exit 1; }
[ "$(id -u)" = 0 ] || fail 'Jalankan sebagai root'
NODE=$(hostname | tr '[:upper:]' '[:lower:]')
MODE=${1:-apply}
case "$MODE" in apply|--boot|--verify) ;; *) fail 'Gunakan apply, --boot atau --verify';; esac
ROLE=frontend
EXPECT_LAST=3

IP=$(ip -4 -o addr show dev eth0 | awk '{split($4,a,"/"); print a[1]; exit}')
[ -n "$IP" ] || fail 'eth0 belum punya IPv4; selesaikan nomor 1'
PREFIX=${PREFIX_OVERRIDE:-$(echo "$IP" | awk -F. '{print $1 "." $2}')}
[ "$IP" = "$PREFIX.4.$EXPECT_LAST" ] || fail "IP node $NODE tidak sesuai pemetaan: $IP"
GOJO=$PREFIX.1.4
GETO=$PREFIX.4.2
ROOT=/root/no14
verify() {
  nginx -t
  service nginx status
  service "$FPM" status
  php -l /var/www/jarkom14/index.php
}
if [ "$MODE" != --verify ]; then
  mkdir -p "$ROOT" /etc/jarkom14
  mkdir -p "$ROOT/deb-cache"
  if [ "$MODE" = --boot ] && ! command -v nginx >/dev/null 2>&1; then
    if ls "$ROOT/deb-cache/"*.deb >/dev/null 2>&1; then
      dpkg -i "$ROOT/deb-cache/"*.deb || true
    fi
  fi
  if [ "$MODE" = apply ] || ! command -v nginx >/dev/null 2>&1 || ! command -v php >/dev/null 2>&1 || ! php -r 'exit(extension_loaded("pdo_mysql") ? 0 : 1);' || ! ls /etc/init.d/php*-fpm >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get -o APT::Keep-Downloaded-Packages=true -o Binary::apt-get::APT::Keep-Downloaded-Packages=true install -y nginx php-fpm php-cli php-mysql curl
    for pkg in /var/cache/apt/archives/*.deb; do
      [ ! -f "$pkg" ] || cp "$pkg" "$ROOT/deb-cache/"
    done
  fi
fi
FPM_PATH=$(find /etc/init.d -maxdepth 1 -name 'php*-fpm' -type f | sort -V | tail -n 1)
[ -n "$FPM_PATH" ] || fail 'PHP-FPM belum terpasang; jalankan mode apply'
FPM=${FPM_PATH##*/}
PHPVER=${FPM#php}; PHPVER=${PHPVER%-fpm}
if [ "$MODE" = --verify ]; then verify; exit; fi


mkdir -p /var/www/jarkom14 /etc/nginx/sites-available /etc/nginx/sites-enabled
STAMP=$(date +%Y%m%d-%H%M%S)-$$
BACKUP=$ROOT/backup-$STAMP
mkdir -p "$BACKUP"
cp -a /etc/nginx/sites-enabled "$BACKUP/"
[ ! -f /etc/nginx/sites-available/jarkom14 ] || cp -a /etc/nginx/sites-available/jarkom14 "$BACKUP/site.conf"
[ ! -f /var/www/jarkom14/index.php ] || cp -a /var/www/jarkom14/index.php "$BACKUP/index.php"

  ALLOWED=$GOJO
  cat > /var/www/jarkom14/index.php <<'FRONTEND_PHP'
<?php
declare(strict_types=1);
header('Content-Type: text/html; charset=utf-8');
$host = htmlspecialchars(gethostname() ?: 'unknown', ENT_QUOTES, 'UTF-8');
?><!doctype html>
<html lang="id"><meta charset="utf-8"><title>Jujutsu K46</title>
<body><h1>Jujutsu High — K46</h1><p>Frontend worker: <strong><?= $host ?></strong></p></body></html>
FRONTEND_PHP
chown -R root:www-data /var/www/jarkom14
chmod 755 /var/www/jarkom14
chmod 644 /var/www/jarkom14/index.php
php -l /var/www/jarkom14/index.php

# ACL uses the actual TCP peer; real_ip must not rewrite it on these workers.
cat > /etc/nginx/sites-available/jarkom14 <<'NGINX_SITE'
server {
    listen 80 default_server;
    server_name jujutsu.k46.com www.jujutsu.k46.com frontend.k46.com api.k46.com;
    root /var/www/jarkom14;
    index index.php;
    allow __ALLOWED__;
    deny all;
    access_log /var/log/nginx/jarkom14-access.log;
    error_log /var/log/nginx/jarkom14-error.log;
    location / { try_files $uri /index.php$is_args$args; }
    location = /index.php {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME /var/www/jarkom14/index.php;
        fastcgi_pass unix:/run/php/php__PHPVER__-fpm.sock;
    }
    location ~ \.php$ { return 404; }
    location ~ /\. { deny all; }
}
NGINX_SITE
sed -i "s/__ALLOWED__/$ALLOWED/g; s/__PHPVER__/$PHPVER/g" /etc/nginx/sites-available/jarkom14
# Disable only the distribution default; other existing virtual hosts stay intact.
if [ -e /etc/nginx/sites-enabled/default ] || [ -L /etc/nginx/sites-enabled/default ]; then
  mv /etc/nginx/sites-enabled/default "$BACKUP/default-enabled"
fi
ln -sfn /etc/nginx/sites-available/jarkom14 /etc/nginx/sites-enabled/jarkom14
if ! nginx -t; then
  rm -f /etc/nginx/sites-enabled/jarkom14
  [ ! -f "$BACKUP/site.conf" ] || cp -a "$BACKUP/site.conf" /etc/nginx/sites-available/jarkom14
  [ ! -e "$BACKUP/default-enabled" ] && [ ! -L "$BACKUP/default-enabled" ] || mv "$BACKUP/default-enabled" /etc/nginx/sites-enabled/default
  fail "nginx -t gagal. Backup konfigurasi: $BACKUP; layanan belum direload"
fi
service "$FPM" restart
if service nginx status >/dev/null 2>&1; then service nginx reload; else service nginx start; fi

# Persist script and startup without replacing previous question startup hooks.
SELF=$(readlink -f "$0")
[ "$SELF" = /root/soal_14.sh ] || cp "$SELF" /root/soal_14.sh
chmod 700 /root/soal_14.sh
[ -f /root/init.sh ] || printf '#!/bin/sh\n' > /root/init.sh
# Insert before a final exit 0, if present, so the hook is reachable.
if ! grep -qF '# JARKOM-NO14' /root/init.sh; then
  awk '/^[[:space:]]*exit[[:space:]]+0[[:space:]]*$/ && !done {print "sh /root/soal_14.sh --boot >> /root/soal_14.log 2>&1 # JARKOM-NO14"; done=1} {print} END {if(!done) print "sh /root/soal_14.sh --boot >> /root/soal_14.log 2>&1 # JARKOM-NO14"}' /root/init.sh > "$ROOT/init.candidate"
  sh -n "$ROOT/init.candidate"
  cp /root/init.sh "$BACKUP/init.sh"
  cat "$ROOT/init.candidate" > /root/init.sh
fi
chmod 755 /root/init.sh
echo "INSTALLED $NODE ($ROLE): allowed proxy=$ALLOWED, prefix=$PREFIX"
if [ "$MODE" = --boot ]; then
  nginx -t
  echo 'Startup worker selesai; database diverifikasi lewat --verify'
else
  verify
fi
