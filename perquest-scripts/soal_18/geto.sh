#!/bin/sh
# Soal 18: kirara backup, passive health check primary 2 kegagalan/5 detik.
# Node: geto; file repo: perquest-scripts/soal_18/geto.sh
set -eu
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
fail() { echo "FAIL: $*" >&2; exit 1; }
[ "$(hostname | tr '[:upper:]' '[:lower:]')" = geto ] || fail "Hanya untuk geto"
[ "$(id -u)" = 0 ] || fail "Jalankan sebagai root"
MODE=${1:-apply}
case "$MODE" in apply|--boot|--verify) ;; *) fail 'Mode: apply, --boot, --verify';; esac
CONF=/etc/nginx/conf.d/soal15.conf
[ -f "$CONF" ] && [ -f /root/init.sh ] || fail 'Selesaikan soal 15 dan 17 terlebih dahulu'
nginx -t
service nginx status >/dev/null 2>&1 || fail 'Nginx geto belum aktif'
grep -Fq 'set_real_ip_from 192.234.1.4;' "$CONF" || fail 'Trusted proxy soal 17 belum ada'
if [ "$MODE" = --verify ]; then
    grep -F 'server 192.234.4.5:80 weight=3 max_fails=2 fail_timeout=5s;' "$CONF"
    grep -F 'server 192.234.4.6:80 weight=1 max_fails=2 fail_timeout=5s;' "$CONF"
    grep -F 'server 192.234.4.7:80 backup;' "$CONF"
    grep -F 'proxy_next_upstream_tries 3;' "$CONF"
    service nginx status
    echo 'PASS: api_cluster primary nanami/todo 3:1, kirara backup; perlu uji gangguan layanan'
    exit 0
fi
STATE=/root/no18
mkdir -p "$STATE"
BACKUP=$(mktemp -d "$STATE/backup-XXXXXX")
FILES='/etc/nginx/conf.d/soal15.conf /root/init.sh'
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

awk '
/^[[:space:]]*server 192\.234\.4\.5:80 / {print "    server 192.234.4.5:80 weight=3 max_fails=2 fail_timeout=5s;"; a++; next}
/^[[:space:]]*server 192\.234\.4\.6:80 / {print "    server 192.234.4.6:80 weight=1 max_fails=2 fail_timeout=5s;"; print "    server 192.234.4.7:80 backup;"; b++; next}
/^[[:space:]]*server 192\.234\.4\.7:80 / {next}
/^[[:space:]]*proxy_next_upstream(_tries|_timeout)?[[:space:]]/ {next}
/^[[:space:]]*proxy_connect_timeout[[:space:]]/ {
    print "        proxy_connect_timeout 1s;"
    print "        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;"
    print "        proxy_next_upstream_tries 3;"
    print "        proxy_next_upstream_timeout 8s;"
    c++; next
}
{print}
END {if(a!=1 || b!=1 || c!=1)exit 42}
' "$CONF" > "$BACKUP/config.candidate" || fail 'Bentuk konfigurasi geto berbeda; tidak dipasang'
cat "$BACKUP/config.candidate" > "$CONF"

# Hanya tambah hook soal ini, pertahankan isi startup sebelumnya.
HOOK='sh /root/soal_18.sh --boot >> /root/soal_18.log 2>&1 # JARKOM-NO18'
if ! grep -qF '# JARKOM-NO18' /root/init.sh; then
    awk -v hook="$HOOK" '/^[[:space:]]*exit[[:space:]]+0[[:space:]]*$/ && !done {print hook; done=1} {print} END {if(!done)print hook}' /root/init.sh > "$BACKUP/init.candidate"
    sh -n "$BACKUP/init.candidate"
    cat "$BACKUP/init.candidate" > /root/init.sh
fi
if [ "$(readlink -f "$0")" != /root/soal_18.sh ]; then cp "$0" /root/soal_18.sh; fi
chmod 700 /root/soal_18.sh
nginx -t
RELOADED=1
service nginx reload
COMMITTED=1
trap - EXIT HUP INT TERM
echo "PASS konfigurasi soal 18; backup=$BACKUP"
