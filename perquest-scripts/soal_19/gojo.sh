#!/bin/sh
# Soal 19: cache frontend 10 menit, limit API 10r/s/IP, log untuk audit.
# Node: gojo; file repo: perquest-scripts/soal_19/gojo.sh
set -eu
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
fail() { echo "FAIL: $*" >&2; exit 1; }
[ "$(hostname | tr '[:upper:]' '[:lower:]')" = gojo ] || fail "Hanya untuk gojo"
[ "$(id -u)" = 0 ] || fail "Jalankan sebagai root"
MODE=${1:-apply}
case "$MODE" in apply|--boot|--verify) ;; *) fail 'Mode: apply, --boot, --verify';; esac
CONF=/etc/nginx/conf.d/soal16.conf
DEFS=/etc/nginx/conf.d/00-soal19.conf
API=/etc/nginx/snippets/soal19-api.conf
LIMIT=/etc/nginx/snippets/soal19-enforcement.conf
[ -f "$CONF" ] && [ -f /root/init.sh ] || fail 'Soal 16 belum tersedia'
nginx -t
service nginx status >/dev/null 2>&1 || fail 'Nginx belum aktif'
grep -Fq 'proxy_set_header X-Real-IP $remote_addr;' "$CONF" || fail 'Terapkan soal 17 dahulu'
if [ "$MODE" = --verify ]; then
    grep -F 'rate=10r/s;' "$DEFS"
    grep -F 'proxy_cache_valid 200 10m;' "$CONF"
    grep -F 'X-Cache-Status' "$CONF"
    grep -F 'limit_req_status 429;' "$API"
    cat "$LIMIT"
    echo 'PASS konfigurasi 19; lanjutkan tes cache dan rate secara terpisah'
    exit 0
fi
STATE=/root/no19
mkdir -p "$STATE"
BACKUP=$(mktemp -d "$STATE/backup-XXXXXX")
FILES='/etc/nginx/conf.d/soal16.conf /etc/nginx/conf.d/00-soal19.conf /etc/nginx/snippets/soal19-api.conf /etc/nginx/snippets/soal19-enforcement.conf /root/init.sh'
for F in $FILES; do
    mkdir -p "$BACKUP$(dirname "$F")"
    if [ -f "$F" ]; then cp -p "$F" "$BACKUP$F"; fi
done
nginx -T > "$BACKUP/nginx-before.txt" 2>&1
COMMITTED=0; RELOADED=0
rollback() {
    RC=$?; trap - EXIT HUP INT TERM
    if [ "$COMMITTED" = 0 ]; then
        for F in $FILES; do
            if [ -f "$BACKUP$F" ]; then cp -p "$BACKUP$F" "$F"; else rm -f "$F"; fi
        done
        if [ "$RELOADED" = 1 ]; then nginx -t && service nginx reload || true; fi
        echo "FAIL: konfigurasi dikembalikan; backup=$BACKUP" >&2
        [ "$RC" != 0 ] || RC=1
    fi
    exit "$RC"
}
trap rollback EXIT
trap 'exit 130' HUP INT TERM

mkdir -p /etc/nginx/snippets /var/cache/nginx/soal19
chown www-data:www-data /var/cache/nginx/soal19
chmod 750 /var/cache/nginx/soal19
cat > "$DEFS" <<'NGINX_DEFS'
proxy_cache_path /var/cache/nginx/soal19 levels=1:2 keys_zone=frontend_cache:10m max_size=64m inactive=10m use_temp_path=off;
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
log_format soal19 escape=json '{"ts":"$time_iso8601","run":"$http_x_test_run","client":"$remote_addr","request":"$request","status":$status,"upstream":"$upstream_addr","upstream_status":"$upstream_status","cache":"$upstream_cache_status","limit":"$limit_req_status","request_time":$request_time,"upstream_time":"$upstream_response_time"}';
NGINX_DEFS
cat > "$CONF" <<'NGINX_CONF'
upstream frontend_cluster {
    zone frontend_cluster 64k;
    server 192.234.4.3:80;
    server 192.234.4.4:80;
}
log_format soal16 '$remote_addr [$time_local] "$request" host=$host status=$status upstream=$upstream_addr upstream_status=$upstream_status';
server {
    listen 80 default_server;
    server_name jujutsu.k46.com www.jujutsu.k46.com;
    access_log /var/log/nginx/soal16-access.log soal16;
    access_log /var/log/nginx/soal19-access.log soal19;
    error_log /var/log/nginx/soal19-error.log;
    proxy_http_version 1.1;
    proxy_set_header Connection "";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $remote_addr;
    proxy_connect_timeout 3s;
    proxy_read_timeout 15s;
    proxy_next_upstream off;
    location = /api {
        include /etc/nginx/snippets/soal19-api.conf;
    }
    location ^~ /api/ {
        include /etc/nginx/snippets/soal19-api.conf;
    }
    location / {
        proxy_pass http://frontend_cluster;
        proxy_cache frontend_cache;
        proxy_cache_key "$scheme|$host|$request_uri";
        proxy_cache_valid 200 10m;
        proxy_cache_lock on;
        add_header X-Cache-Status $upstream_cache_status always;
        add_header X-Gojo-Route frontend always;
        add_header X-Gojo-Upstream $upstream_addr always;
    }
}
NGINX_CONF
cat > "$API" <<'NGINX_API'
limit_req zone=api_limit;
limit_req_status 429;
limit_req_log_level notice;
include /etc/nginx/snippets/soal19-enforcement.conf;
proxy_cache off;
proxy_pass http://192.234.4.2:80;
add_header X-Gojo-Route api always;
add_header X-Gojo-Upstream $upstream_addr always;
add_header X-Rate-Limit-Status $limit_req_status always;
NGINX_API
# Pembatasan selalu aktif setelah pemasangan/boot; baseline soal 20 hanya sementara.
printf 'limit_req_dry_run off;\n' > "$LIMIT"

# Hanya tambah hook soal ini, pertahankan isi startup sebelumnya.
HOOK='sh /root/soal_19.sh --boot >> /root/soal_19.log 2>&1 # JARKOM-NO19'
if ! grep -qF '# JARKOM-NO19' /root/init.sh; then
    awk -v hook="$HOOK" '/^[[:space:]]*exit[[:space:]]+0[[:space:]]*$/ && !done {print hook; done=1} {print} END {if(!done)print hook}' /root/init.sh > "$BACKUP/init.candidate"
    sh -n "$BACKUP/init.candidate"
    cat "$BACKUP/init.candidate" > /root/init.sh
fi
if [ "$(readlink -f "$0")" != /root/soal_19.sh ]; then cp "$0" /root/soal_19.sh; fi
chmod 700 /root/soal_19.sh
nginx -t
RELOADED=1
service nginx reload
COMMITTED=1
trap - EXIT HUP INT TERM
echo "PASS konfigurasi soal 19; backup=$BACKUP"
