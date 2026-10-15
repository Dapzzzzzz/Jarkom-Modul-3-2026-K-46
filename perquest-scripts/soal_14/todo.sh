#!/bin/sh
# Soal 14
#   - todo: API Nginx/PHP-FPM, log ke yaga, hanya menerima geto.
#   - File repo: perquest-scripts/soal_14/todo.sh
[ "$(hostname | tr '[:upper:]' '[:lower:]')" = todo ] || { echo "Hanya untuk node todo" >&2; exit 1; }

set -eu
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
fail() { echo "FAIL: $*" >&2; exit 1; }
[ "$(id -u)" = 0 ] || fail 'Jalankan sebagai root'
NODE=$(hostname | tr '[:upper:]' '[:lower:]')
MODE=${1:-apply}
case "$MODE" in apply|--boot|--verify) ;; *) fail 'Gunakan apply, --boot atau --verify';; esac
ROLE=api
EXPECT_LAST=6

IP=$(ip -4 -o addr show dev eth0 | awk '{split($4,a,"/"); print a[1]; exit}')
[ -n "$IP" ] || fail 'eth0 belum punya IPv4; selesaikan nomor 1'
PREFIX=${PREFIX_OVERRIDE:-$(echo "$IP" | awk -F. '{print $1 "." $2}')}
[ "$IP" = "$PREFIX.4.$EXPECT_LAST" ] || fail "IP node $NODE tidak sesuai pemetaan: $IP"
GOJO=$PREFIX.1.4
GETO=$PREFIX.4.2
ROOT=/root/no14
if [ "$MODE" != --verify ] && [ ! -f "$ROOT/db.json" ] && [ ! -f /etc/jarkom14/db.json ] && [ -z "${DB_PASS:-}" ]; then
  fail "Isi DB_PASS dari akun aplikasi nomor 13 untuk instalasi pertama"
fi
verify() {
  nginx -t
  service nginx status
  service "$FPM" status
  php -l /var/www/jarkom14/index.php
  if [ "$ROLE" = api ]; then
    php -r '$c=json_decode(file_get_contents("/etc/jarkom14/db.json"),true,512,JSON_THROW_ON_ERROR); $d=new PDO("mysql:host=".$c["host"].";port=".$c["port"].";dbname=".$c["database"],$c["username"],$c["password"],[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION,PDO::ATTR_TIMEOUT=>4]); $d->query("SELECT client_ip,worker,method,path FROM request_logs LIMIT 0"); echo "DB connection and columns PASS (read only)\n";'
  fi
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

  ALLOWED=$GETO
  cat > /var/www/jarkom14/index.php <<'API_PHP'
<?php
declare(strict_types=1);
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
$worker = gethostname() ?: 'unknown';
try {
    $cfg = json_decode(file_get_contents('/etc/jarkom14/db.json'), true, 512, JSON_THROW_ON_ERROR);
    $peer = $_SERVER['REMOTE_ADDR'] ?? '';
    // Only trust the verified value from geto, never arbitrary X-Forwarded-For.
    // Before no17 is configured, the logged address is the immediate proxy.
    $client = $peer;
    $forwarded = $_SERVER['HTTP_X_REAL_IP'] ?? '';
    if ($peer === $cfg['trusted_geto'] && filter_var($forwarded, FILTER_VALIDATE_IP)) {
        $client = $forwarded;
    }
    $pdo = new PDO(
        sprintf('mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4', $cfg['host'], $cfg['port'], $cfg['database']),
        $cfg['username'], $cfg['password'],
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_EMULATE_PREPARES => false, PDO::ATTR_TIMEOUT => 4]
    );
    $stmt = $pdo->prepare('INSERT INTO request_logs (client_ip, worker, method, path) VALUES (?, ?, ?, ?)');
    $stmt->execute([$client, substr($worker,0,32), substr($_SERVER['REQUEST_METHOD'] ?? 'GET',0,8), substr($_SERVER['REQUEST_URI'] ?? '/api',0,255)]);
    echo json_encode(['ok'=>true, 'worker'=>$worker, 'client_ip'=>$client, 'log_id'=>$pdo->lastInsertId()], JSON_UNESCAPED_SLASHES), "\n";
} catch (Throwable $e) {
    error_log('JARKOM14 database logging failed: '.$e->getMessage());
    http_response_code(503);
    echo json_encode(['ok'=>false, 'worker'=>$worker, 'error'=>'database_log_failed']), "\n";
}
API_PHP
  # Pertahankan konfigurasi DB lama; instalasi pertama membaca password dari DB_PASS.
  if [ -f "$ROOT/db.json" ]; then
    cp "$ROOT/db.json" /etc/jarkom14/db.json
  elif [ ! -f /etc/jarkom14/db.json ]; then
    cat > /etc/jarkom14/db.json <<'DB_JSON'
{
  "host": "192.234.4.8",
  "port": 3306,
  "database": "db_shibuya_K46",
  "username": "shibuya",
  "password": ""
}
DB_JSON
    php -r '$p="/etc/jarkom14/db.json"; $c=json_decode(file_get_contents($p),true,512,JSON_THROW_ON_ERROR); $c["password"]=getenv("DB_PASS"); $c["host"]=$argv[1]; $c["trusted_geto"]=$argv[2]; file_put_contents($p,json_encode($c,JSON_PRETTY_PRINT)."\n");' "$PREFIX.4.8" "$GETO"
  fi
  chown root:www-data /etc/jarkom14/db.json
  chmod 640 /etc/jarkom14/db.json
  cp /etc/jarkom14/db.json "$ROOT/db.json"
  chmod 600 "$ROOT/db.json"
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
