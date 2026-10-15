#!/bin/sh
# Soal 17
#   - maki: uji tambahan: geto mengabaikan header palsu dari node selain gojo.
#   - File repo: perquest-scripts/soal_17/maki.sh
set -eu
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
fail() { echo "FAIL: $*" >&2; exit 1; }
[ "$(hostname | tr '[:upper:]' '[:lower:]')" = maki ] || fail "Hanya untuk maki"
# Uji langsung geto dari Data Center, bukan uji frontend maki.
command -v curl >/dev/null 2>&1 || fail 'curl belum tersedia'
TAG=$(date +%s)-maki-$$
DIR=/root/no17-verifikasi-$TAG
mkdir -p "$DIR"
CODE=$(curl --noproxy '*' --interface 192.234.4.3 --max-time 15 -sS \
    -H 'Host: api.k46.com' -H 'X-Real-IP: 203.0.113.123' \
    -H 'X-Forwarded-For: 203.0.113.123, 198.51.100.77' \
    -D "$DIR/headers.txt" -o "$DIR/body.json" -w '%{http_code}' \
    "http://192.234.4.2/api/soal17-$TAG/direct-geto-spoof")
cat "$DIR/body.json"
[ "$CODE" = 200 ] || fail "HTTP=$CODE"
grep -q '"ok":true' "$DIR/body.json" || fail 'Log API gagal'
grep -q '"client_ip":"192.234.4.3"' "$DIR/body.json" || fail 'Geto mempercayai header dari sumber selain gojo'
echo 'PASS: geto mencatat 192.234.4.3, header palsu dari maki diabaikan'
