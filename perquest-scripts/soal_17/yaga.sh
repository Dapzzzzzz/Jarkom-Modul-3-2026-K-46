#!/bin/sh
# Soal 17
#   - yaga: verifikasi SELECT saja: cocokkan client_ip database dengan hasil client.
#   - File repo: perquest-scripts/soal_17/yaga.sh
set -eu
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
fail() { echo "FAIL: $*" >&2; exit 1; }
[ "$(hostname | tr '[:upper:]' '[:lower:]')" = yaga ] || fail "Hanya untuk yaga"
# Jalankan dua kali, masing-masing menggunakan TAG/IP yang dicetak client.
# Tidak mengubah user, password, tabel, data, service, atau replikasi database.
[ "$#" = 2 ] || fail 'Cara pakai: sh /root/soal_17.sh TAG IP_CLIENT'
TAG=$1
EXPECTED=$2
printf '%s\n' "$TAG" | grep -Eq '^[0-9]+-(itadori|kusakabe)-[0-9]+$' || fail 'TAG tidak valid'
printf '%s\n' "$EXPECTED" | awk -F. 'NF==4 && $1==192 && $2==234 && ($3==2 || $3==3) && $4~/^[0-9]+$/ && $4>=1 && $4<=254 {ok=1} END {exit !ok}' || fail 'IP client harus IPv4 Network 2/3'
case "$TAG:$EXPECTED" in
    *-itadori-*:192.234.2.*|*-kusakabe-*:192.234.3.*) ;;
    *) fail 'TAG dan Network client tidak cocok';;
esac
command -v mysql >/dev/null 2>&1 || fail 'mysql client belum tersedia'
DB=db_shibuya_K46
WHERE="path LIKE '/api/soal17-$TAG/%'"
mysql "$DB" -e "SELECT id,client_ip,worker,method,path FROM request_logs WHERE $WHERE ORDER BY id;"
TOTAL=$(mysql -N -B "$DB" -e "SELECT COUNT(*) FROM request_logs WHERE $WHERE;")
BAD=$(mysql -N -B "$DB" -e "SELECT COUNT(*) FROM request_logs WHERE $WHERE AND (client_ip IS NULL OR client_ip <> '$EXPECTED');")
SPOOF=$(mysql -N -B "$DB" -e "SELECT COUNT(*) FROM request_logs WHERE $WHERE AND path LIKE '%-spoof';")
[ "$TOTAL" = 4 ] || fail "Ada $TOTAL baris, seharusnya 4 untuk TAG ini"
[ "$SPOOF" = 2 ] || fail "Ada $SPOOF uji header palsu, seharusnya 2"
[ "$BAD" = 0 ] || fail "$BAD baris menyimpan IP yang keliru"
echo "PASS database: 4/4 request TAG=$TAG client_ip=$EXPECTED, termasuk 2 uji header palsu"
