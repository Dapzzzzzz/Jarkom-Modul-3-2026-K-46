#!/bin/sh
# Soal 17
#   - geto: konfigurasi header IP asli; backup, nginx -t, reload, dan startup.
#   - File repo: perquest-scripts/soal_17/geto.sh
set -eu
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
fail() { echo "FAIL: $*" >&2; exit 1; }
[ "$(hostname | tr '[:upper:]' '[:lower:]')" = geto ] || fail "Hanya untuk geto"
[ "$(id -u)" = 0 ] || fail 'Jalankan sebagai root'
MODE=${1:-apply}
case "$MODE" in apply|--boot|--verify) ;; *) fail 'Mode: apply, --boot, --verify';; esac
CONF=/etc/nginx/conf.d/soal15.conf
STATE=/root/no17
SELF_TARGET=/root/soal_17.sh
HOOK='sh /root/soal_17.sh --boot >> /root/soal_17.log 2>&1 # JARKOM-NO17'
[ -f "$CONF" ] || fail 'Konfigurasi soal 15 belum ada; pasang soal 15 dahulu'
ip -4 -o addr show | awk '{split($4,a,"/"); print a[1]}' | grep -qx '192.234.4.2' || fail 'IP node harus 192.234.4.2'
command -v nginx >/dev/null 2>&1 || fail 'Nginx belum terpasang'
nginx -t
service nginx status >/dev/null 2>&1 || fail 'Nginx belum aktif; cek soal 15 dahulu'
nginx -V 2>&1 | grep -q -- '--with-http_realip_module' || fail 'Nginx memerlukan http_realip_module; tidak ada paket yang dipasang otomatis'

if [ "$MODE" = --verify ]; then
    grep -F 'proxy_set_header X-Real-IP $remote_addr;' "$CONF"
    grep -F 'proxy_set_header X-Forwarded-For $remote_addr;' "$CONF"
    grep -F 'set_real_ip_from 192.234.1.4;' "$CONF"
    grep -F 'real_ip_header X-Forwarded-For;' "$CONF"
    grep -F 'real_ip_recursive on;' "$CONF"
    echo 'PASS konfigurasi geto; uji IP dan database dijalankan terpisah dari client/yaga'
    exit 0
fi

# Gojo adalah edge proxy: jangan menerima penggantian remote_addr dari header klien.
:
[ -f /root/init.sh ] || fail 'Startup soal sebelumnya belum tersedia: /root/init.sh'
mkdir -p "$STATE"
BACKUP=$(mktemp -d "$STATE/backup-XXXXXX")
cp -p "$CONF" "$BACKUP/config.before"
cp -p /root/init.sh "$BACKUP/init.before"
if [ -f "$SELF_TARGET" ]; then cp -p "$SELF_TARGET" "$BACKUP/script.before"; fi
nginx -T > "$BACKUP/nginx-before.txt" 2>&1

# Batasi patch pada file soal sebelumnya, jangan mengganti seluruh nginx.conf.
# Header XFF dikirim sebagai satu IP yang telah diverifikasi, bukan rantai input klien.
if ! awk -v role=geto 'BEGIN { block=0; real=0; xff=0; servers=0; bad=0 }
/^[[:space:]]*# BEGIN SOAL17 TRUST$/ { if (block) bad=1; block=1; next }
/^[[:space:]]*# END SOAL17 TRUST$/ { if (!block) bad=1; block=0; next }
block { next }
/^[[:space:]]*(set_real_ip_from|real_ip_header|real_ip_recursive)[[:space:]]/ { bad=1 }
/^[[:space:]]*# (Header IP asli dikonfigurasi pada nomor 17\.|Verifikasi IP client asli merupakan nomor 17\.)$/ { next }
/^[[:space:]]*server_name[[:space:]]/ {
    servers++; print
    if (role == "geto") {
        print "    # BEGIN SOAL17 TRUST"
        print "    set_real_ip_from 192.234.1.4;"
        print "    real_ip_header X-Forwarded-For;"
        print "    real_ip_recursive on;"
        print "    # END SOAL17 TRUST"
    }
    next
}
/^[[:space:]]*proxy_set_header[[:space:]]+X-Real-IP[[:space:]]/ {
    real++; sub(/X-Real-IP[[:space:]].*$/, "X-Real-IP $remote_addr;"); print; next
}
/^[[:space:]]*proxy_set_header[[:space:]]+X-Forwarded-For[[:space:]]/ {
    xff++; sub(/X-Forwarded-For[[:space:]].*$/, "X-Forwarded-For $remote_addr;"); print; next
}
{ print }
END { if (block || bad || real != 1 || xff != 1 || servers != 1) exit 42 }' "$CONF" > "$BACKUP/config.candidate"; then
    fail "Format konfigurasi berbeda dari soal 15; file aktif belum diubah. Backup=$BACKUP"
fi

# Tambahkan startup sesudah hook 14-16 agar patch tetap berlaku sesudah boot.
if grep -qF '# JARKOM-NO17' /root/init.sh; then
    grep -qFx "$HOOK" /root/init.sh || fail 'Hook nomor 17 berbeda; periksa manual'
    cp -p /root/init.sh "$BACKUP/init.candidate"
else
    awk -v hook="$HOOK" '/^[[:space:]]*exit[[:space:]]+0[[:space:]]*$/ && !done {print hook; done=1} {print} END {if(!done)print hook}' /root/init.sh > "$BACKUP/init.candidate"
fi
sh -n "$BACKUP/init.candidate"

COMMITTED=0
RELOAD_ATTEMPTED=0
rollback() {
    RC=$?
    trap - EXIT HUP INT TERM
    if [ "$COMMITTED" = 0 ]; then
        cp -p "$BACKUP/config.before" "$CONF"
        cp -p "$BACKUP/init.before" /root/init.sh
        if [ -f "$BACKUP/script.before" ]; then
            cp -p "$BACKUP/script.before" "$SELF_TARGET"
        elif [ "$(readlink -f "$0")" != "$SELF_TARGET" ]; then
            rm -f "$SELF_TARGET"
        fi
        if [ "$RELOAD_ATTEMPTED" = 1 ]; then
            if nginx -t; then service nginx reload || true; fi
        fi
        echo "FAIL: file yang disentuh dikembalikan. Backup=$BACKUP" >&2
        [ "$RC" != 0 ] || RC=1
    fi
    exit "$RC"
}
trap rollback EXIT
trap 'exit 1' HUP INT TERM
cat "$BACKUP/config.candidate" > "$CONF"
cat "$BACKUP/init.candidate" > /root/init.sh
if [ "$(readlink -f "$0")" != "$SELF_TARGET" ]; then cp "$0" "$SELF_TARGET"; fi
chmod 700 "$SELF_TARGET"
nginx -t
RELOAD_ATTEMPTED=1
service nginx reload
COMMITTED=1
trap - EXIT HUP INT TERM
echo "PASS: geto meneruskan IP terverifikasi; backup=$BACKUP"
echo 'Belum membuktikan database. Lanjutkan verifikasi client Network 2, Network 3, lalu yaga.'
