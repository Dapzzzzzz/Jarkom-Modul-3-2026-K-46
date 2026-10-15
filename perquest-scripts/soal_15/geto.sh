#!/bin/sh
# Soal 15
#   - geto: upstream api_cluster nanami:todo = 3:1, port 80.
#   - File repo: perquest-scripts/soal_15/geto.sh
[ "$(hostname | tr '[:upper:]' '[:lower:]')" = geto ] || { echo "Hanya untuk node geto" >&2; exit 1; }

# Soal 15: geto sebagai internal load balancer API, Weighted Round Robin 3:1.
# ==== NODE GETO ====
# nanami = 192.234.4.5 (weight 3), todo = 192.234.4.6 (weight 1).
# Jalankan: sh /root/soal_15.sh ; cek: sh /root/soal_15.sh --verify.
set -eu
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
[ "$(id -u)" = 0 ] || { echo 'Jalankan sebagai root'; exit 1; }
[ "$(hostname | tr '[:upper:]' '[:lower:]')" = geto ] || { echo 'Hanya untuk geto'; exit 1; }
MODE=${1:-apply}
case "$MODE" in apply|--boot|--verify) ;; *) echo 'Mode: apply, --boot, --verify'; exit 1;; esac
IP=$(ip -4 -o addr show eth0 | awk '{split($4,a,"/");print a[1];exit}')
PREFIX=$(printf '%s\n' "$IP" | awk -F. '{print $1"."$2}')
[ "$IP" = "$PREFIX.4.2" ] || { echo 'IP geto harus PREFIX.4.2'; exit 1; }
ROOT=/root/no15
CONF=/etc/nginx/conf.d/soal15.conf

# ==== VERIFIKASI 1: KONFIGURASI DAN SERVICE (NODE GETO) ====
if [ "$MODE" = --verify ]; then
    nginx -t
    service nginx status
    cat "$CONF"
    grep -F "server $PREFIX.4.5:80 weight=3;" "$CONF"
    grep -F "server $PREFIX.4.6:80 weight=1;" "$CONF"
    echo 'PASS: api_cluster nanami:todo = 3:1, geto port 80'
    exit
fi

# ==== INSTALASI NGINX ====
if ! command -v nginx >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y nginx curl
fi
mkdir -p "$ROOT" /etc/nginx/conf.d
BACKUP=$ROOT/backup-$(date +%Y%m%d-%H%M%S)-$$
mkdir -p "$BACKUP"
nginx -T > "$BACKUP/nginx-before.txt" 2>&1
[ ! -f "$CONF" ] || cp -a "$CONF" "$BACKUP/soal15.conf"

# ==== UPSTREAM API_CLUSTER: WEIGHTED ROUND ROBIN ====
# zone membagi state penjadwalan antarseluruh worker process Nginx.
# Nginx memakai Weighted Round Robin tanpa directive algoritma tambahan.
cat > "$CONF" <<'NGINX_CONF'
upstream api_cluster {
    zone api_cluster 64k;
    server __PREFIX__.4.5:80 weight=3;
    server __PREFIX__.4.6:80 weight=1;
}

log_format soal15 '$remote_addr [$time_local] "$request" '
                  'status=$status upstream=$upstream_addr upstream_status=$upstream_status';

server {
    listen 80 default_server;
    server_name geto.k46.com api.k46.com;
    access_log /var/log/nginx/soal15-access.log soal15;
    error_log /var/log/nginx/soal15-error.log;

    location / {
        proxy_pass http://api_cluster;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host $host;
        # Verifikasi IP client asli merupakan nomor 17.
        proxy_set_header X-Real-IP "";
        proxy_set_header X-Forwarded-For "";
        proxy_connect_timeout 3s;
        proxy_read_timeout 15s;
        proxy_next_upstream off;
        add_header X-Upstream-Addr $upstream_addr always;
    }
}
NGINX_CONF
sed -i "s/__PREFIX__/$PREFIX/g" "$CONF"

# ==== AKTIFKAN VIRTUAL HOST GETO ====
# Backup lalu nonaktifkan default site bawaan yang masih memakai port 80.
if [ -e /etc/nginx/sites-enabled/default ] || [ -L /etc/nginx/sites-enabled/default ]; then
    mv /etc/nginx/sites-enabled/default "$BACKUP/default-enabled"
fi
if ! nginx -t; then
    if [ -f "$BACKUP/soal15.conf" ]; then cp -a "$BACKUP/soal15.conf" "$CONF"; else rm -f "$CONF"; fi
    if [ -e "$BACKUP/default-enabled" ] || [ -L "$BACKUP/default-enabled" ]; then
        mv "$BACKUP/default-enabled" /etc/nginx/sites-enabled/default
    fi
    echo "FAIL: konfigurasi dikembalikan; backup=$BACKUP" >&2
    exit 1
fi
if service nginx status >/dev/null 2>&1; then service nginx reload; else service nginx start; fi

# ==== STARTUP NOMOR 15 (HOOK LAMA DIPERTAHANKAN) ====
SELF=$(readlink -f "$0")
[ "$SELF" = /root/soal_15.sh ] || cp "$SELF" /root/soal_15.sh
chmod 700 /root/soal_15.sh
[ -f /root/init.sh ] || printf '#!/bin/sh\n' > /root/init.sh
if ! grep -qF '# JARKOM-NO15' /root/init.sh; then
    awk '/^[[:space:]]*exit[[:space:]]+0[[:space:]]*$/ && !done {print "sh /root/soal_15.sh --boot >> /root/soal_15.log 2>&1 # JARKOM-NO15";done=1} {print} END {if(!done)print "sh /root/soal_15.sh --boot >> /root/soal_15.log 2>&1 # JARKOM-NO15"}' /root/init.sh > "$ROOT/init.candidate"
    sh -n "$ROOT/init.candidate"
    cp /root/init.sh "$BACKUP/init.sh"
    cat "$ROOT/init.candidate" > /root/init.sh
fi
chmod 755 /root/init.sh
echo "PASS: geto $IP:80, nanami:todo = 3:1"

# ==== VERIFIKASI 2: RESPONS API (DARI MAKI / NODE DATA CENTER) ====
# curl -i http://192.234.4.2/api/uji-soal15
# Harus HTTP 200, ok:true, worker nanami/todo, header X-Upstream-Addr.

# ==== VERIFIKASI 3: DISTRIBUSI 40 REQUEST (DARI MAKI) ====
# sh /root/soal_15.sh  # pada node maki
# Harapan: nanami=30, todo=10, worker lain=0, seluruh request HTTP 200.
# Jangan gunakan geto port 8080; port itu masih jalur demo nomor 14.
