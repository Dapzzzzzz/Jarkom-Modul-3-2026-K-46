#!/bin/sh
# Soal 16
#   - gojo: dua domain port 80; root ke frontend, /api ke geto.
#   - File repo: perquest-scripts/soal_16/gojo.sh
[ "$(hostname | tr '[:upper:]' '[:lower:]')" = gojo ] || { echo "Hanya untuk node gojo" >&2; exit 1; }

# Soal 16: public reverse proxy gojo, Path-Based Routing pada port 80.
# Domain: jujutsu.k46.com dan www.jujutsu.k46.com.
# / -> maki/panda Round Robin; /api dan /api/... -> geto port 80.
# ==== NODE GOJO ====
set -eu
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export DEBIAN_FRONTEND=noninteractive
[ "$(id -u)" = 0 ] || { echo 'Jalankan sebagai root'; exit 1; }
[ "$(hostname | tr '[:upper:]' '[:lower:]')" = gojo ] || { echo 'Hanya untuk gojo'; exit 1; }
MODE=${1:-apply}
case "$MODE" in apply|--boot|--verify) ;; *) echo 'Mode: apply, --boot, --verify'; exit 1;; esac
IP=$(ip -4 -o addr show eth0 | awk '{split($4,a,"/");print a[1];exit}')
PREFIX=$(printf '%s\n' "$IP" | awk -F. '{print $1"."$2}')
[ "$IP" = "$PREFIX.1.4" ] || { echo 'IP gojo harus PREFIX.1.4'; exit 1; }
ROOT=/root/no16
CONF=/etc/nginx/conf.d/soal16.conf

# ==== VERIFIKASI 1: KONFIGURASI DAN SERVICE GOJO ====
if [ "$MODE" = --verify ]; then
    nginx -t
    service nginx status
    cat "$CONF"
    grep -F 'server_name jujutsu.k46.com www.jujutsu.k46.com;' "$CONF"
    grep -F "proxy_pass http://$PREFIX.4.2:80;" "$CONF"
    echo 'PASS: gojo port 80, root -> frontend, /api -> geto'
    exit
fi

# ==== INSTALASI NGINX ====
if ! command -v nginx >/dev/null 2>&1; then
    apt-get update
    apt-get install -y nginx curl
fi
mkdir -p "$ROOT" /etc/nginx/conf.d
BACKUP=$ROOT/backup-$(date +%Y%m%d-%H%M%S)-$$
mkdir -p "$BACKUP"
nginx -T > "$BACKUP/nginx-before.txt" 2>&1
[ ! -f "$CONF" ] || cp -a "$CONF" "$BACKUP/soal16.conf"

# ==== UPSTREAM FRONTEND: ROUND ROBIN MAKI DAN PANDA ====
cat > "$CONF" <<'NGINX_CONF'
upstream frontend_cluster {
    zone frontend_cluster 64k;
    server __PREFIX__.4.3:80;
    server __PREFIX__.4.4:80;
}

log_format soal16 '$remote_addr [$time_local] "$request" host=$host '
                  'status=$status upstream=$upstream_addr upstream_status=$upstream_status';

server {
    listen 80 default_server;
    server_name jujutsu.k46.com www.jujutsu.k46.com;
    access_log /var/log/nginx/soal16-access.log soal16;
    error_log /var/log/nginx/soal16-error.log;

    proxy_http_version 1.1;
    proxy_set_header Connection "";
    proxy_set_header Host $host;
    # Header IP asli dikonfigurasi pada nomor 17.
    proxy_set_header X-Real-IP "";
    proxy_set_header X-Forwarded-For "";
    proxy_connect_timeout 3s;
    proxy_read_timeout 15s;
    proxy_next_upstream off;

    # ==== PATH /api TEPAT DAN SUBPATH /api/ ====
    # Tanpa URI/trailing slash di proxy_pass: path dan query string tetap utuh.
    location = /api {
        proxy_pass http://__PREFIX__.4.2:80;
        add_header X-Gojo-Route api always;
        add_header X-Gojo-Upstream $upstream_addr always;
    }
    location ^~ /api/ {
        proxy_pass http://__PREFIX__.4.2:80;
        add_header X-Gojo-Route api always;
        add_header X-Gojo-Upstream $upstream_addr always;
    }

    # ==== ROOT / DAN PATH WEB LAINNYA ====
    location / {
        proxy_pass http://frontend_cluster;
        add_header X-Gojo-Route frontend always;
        add_header X-Gojo-Upstream $upstream_addr always;
    }
}
NGINX_CONF
sed -i "s/__PREFIX__/$PREFIX/g" "$CONF"

# ==== AKTIFKAN SERVER PORT 80 ====
# Default site bawaan dibackup; jalur demo nomor 14 port 8080 tetap tersedia.
if [ -e /etc/nginx/sites-enabled/default ] || [ -L /etc/nginx/sites-enabled/default ]; then
    mv /etc/nginx/sites-enabled/default "$BACKUP/default-enabled"
fi
if ! nginx -t; then
    if [ -f "$BACKUP/soal16.conf" ]; then cp -a "$BACKUP/soal16.conf" "$CONF"; else rm -f "$CONF"; fi
    if [ -e "$BACKUP/default-enabled" ] || [ -L "$BACKUP/default-enabled" ]; then
        mv "$BACKUP/default-enabled" /etc/nginx/sites-enabled/default
    fi
    echo "FAIL: konfigurasi dikembalikan; backup=$BACKUP" >&2
    exit 1
fi
if service nginx status >/dev/null 2>&1; then service nginx reload; else service nginx start; fi

# ==== STARTUP NOMOR 16 ====
SELF=$(readlink -f "$0")
[ "$SELF" = /root/soal_16.sh ] || cp "$SELF" /root/soal_16.sh
chmod 700 /root/soal_16.sh
[ -f /root/init.sh ] || printf '#!/bin/sh\n' > /root/init.sh
if ! grep -qF '# JARKOM-NO16' /root/init.sh; then
    awk '/^[[:space:]]*exit[[:space:]]+0[[:space:]]*$/ && !done {print "sh /root/soal_16.sh --boot >> /root/soal_16.log 2>&1 # JARKOM-NO16";done=1} {print} END {if(!done)print "sh /root/soal_16.sh --boot >> /root/soal_16.log 2>&1 # JARKOM-NO16"}' /root/init.sh > "$ROOT/init.candidate"
    sh -n "$ROOT/init.candidate"
    cp /root/init.sh "$BACKUP/init.sh"
    cat "$ROOT/init.candidate" > /root/init.sh
fi
chmod 755 /root/init.sh
echo "PASS: gojo $IP:80, dua domain, / -> maki/panda, /api -> geto"

# ==== VERIFIKASI 2: FRONTEND (DARI ITADORI / KUSAKABE) ====
# sh /root/soal_16.sh frontend  # pada client
# Kedua domain HTTP 200, nama maki/panda, header X-Gojo-Route: frontend.

# ==== VERIFIKASI 3: API (DARI ITADORI / KUSAKABE) ====
# sh /root/soal_16.sh api  # pada client
# /api dan /api/... HTTP 200, ok:true, nanami/todo; X-Gojo-Upstream = geto.
