#!/bin/sh
# Soal 18: verifikasi dan simulasi stop/start layanan Nginx, bukan container.
# Node: nanami; file repo: perquest-scripts/soal_18/nanami.sh
set -eu
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
fail() { echo "FAIL: $*" >&2; exit 1; }
[ "$(hostname | tr '[:upper:]' '[:lower:]')" = nanami ] || fail "Hanya untuk nanami"
[ "$(id -u)" = 0 ] || fail "Jalankan sebagai root"
# Tidak mengubah konfigurasi API. Stop hanya untuk simulasi soal 18.
STATE=/root/no18
MODE=${1:---verify}
mkdir -p "$STATE"
case "$MODE" in
    --verify)
        nginx -t
        service nginx status
        php -l /var/www/jarkom14/index.php
        ;;
    --stop-test)
        service nginx status >/dev/null 2>&1 || fail 'Nginx sudah tidak aktif; tidak mengubah keadaan awal'
        [ ! -f "$STATE/test-token" ] || fail 'Simulasi lain masih aktif'
        TOKEN=$(date +%s)-$$
        printf '%s\n' "$TOKEN" > "$STATE/test-token"
        # Watchdog 45 detik menghidupkan layanan bila sesi pengujian terputus.
        nohup sh -c 'sleep 45; [ -f /root/no18/test-token ] && [ "$(cat /root/no18/test-token)" = "$1" ] && sh /root/soal_18.sh --restore; exit 0' sh "$TOKEN" > "$STATE/watchdog.log" 2>&1 < /dev/null &
        service nginx stop
        echo 'SIMULASI AKTIF: Nginx berhenti sementara; wajib pulihkan dengan --restore'
        ;;
    --restore)
        if [ -f "$STATE/test-token" ]; then
            nginx -t
            if ! service nginx status >/dev/null 2>&1; then service nginx start; fi
            service nginx status
            rm -f "$STATE/test-token"
        else
            service nginx status
        fi
        echo 'PASS: Nginx aktif kembali'
        ;;
    *) fail 'Mode: --verify, --stop-test, --restore';;
esac
