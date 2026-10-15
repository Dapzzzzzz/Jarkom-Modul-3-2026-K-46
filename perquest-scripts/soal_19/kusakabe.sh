#!/bin/sh
# Soal 19: uji MISS/HIT dan burst API 200/429 dengan IP client yang berbeda.
# Node: kusakabe; file repo: perquest-scripts/soal_19/kusakabe.sh
set -eu
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
fail() { echo "FAIL: $*" >&2; exit 1; }
[ "$(hostname | tr '[:upper:]' '[:lower:]')" = kusakabe ] || fail "Hanya untuk kusakabe"
[ "$(id -u)" = 0 ] || fail "Jalankan sebagai root"
DEMO=0
if [ "${1:-}" = --demo ]; then DEMO=1; shift; fi
TEMP_IP=0; TEMP_ROUTE=0
cleanup() {
    [ "$TEMP_ROUTE" = 0 ] || ip route del default via 192.234.3.1 dev eth0
    [ "$TEMP_IP" = 0 ] || ip addr del 192.234.3.250/24 dev eth0
}
trap cleanup EXIT
trap 'exit 130' HUP INT TERM
if [ "$DEMO" = 1 ] && [ -z "$(ip -4 -o addr show eth0)" ]; then
    [ -z "$(ip route show default)" ] || fail 'IP kosong tetapi gateway ada; cek manual'
    arping -D -c 2 -w 3 -I eth0 192.234.3.250 || fail 'IP uji mungkin terpakai'
    ip addr add 192.234.3.250/24 dev eth0; TEMP_IP=1
    ip route add default via 192.234.3.1 dev eth0; TEMP_ROUTE=1
    echo 'IP uji 192.234.3.250; alamat dan route uji dihapus otomatis'
fi
CLIENT=$(ip -4 route get 192.234.1.4 | awk '{for(i=1;i<=NF;i++)if($i=="src"){print $(i+1);exit}}')
case "$CLIENT" in 192.234.3.*) ;; *) fail 'Client belum memiliki IP/gateway Network 3';; esac
command -v curl >/dev/null 2>&1 || fail 'curl belum tersedia'
curl_get() {
    if [ "$DEMO" = 1 ]; then
        curl --noproxy '*' --interface "$CLIENT" --resolve jujutsu.k46.com:80:192.234.1.4 --max-time 15 -sS "$@"
    else
        curl --noproxy '*' --interface "$CLIENT" --max-time 15 -sS "$@"
    fi
}

MODE=${1:-all}
case "$MODE" in cache|rate|all) ;; *) fail 'Mode: [--demo] cache|rate|all';; esac
TAG=$(date +%s)-$$
DIR=/root/no19-verifikasi-$TAG
mkdir -p "$DIR"
if [ "$MODE" = cache ] || [ "$MODE" = all ]; then
    for I in 1 2; do
        CODE=$(curl_get -D "$DIR/cache-$I.headers" -o "$DIR/cache-$I.html" -w '%{http_code}' "http://jujutsu.k46.com/?soal19=$TAG")
        [ "$CODE" = 200 ] || fail "Cache test HTTP=$CODE"
        STATUS=$(awk 'tolower($1)=="x-cache-status:" {gsub("\r","",$2);print $2}' "$DIR/cache-$I.headers")
        if [ "$I" = 1 ]; then [ "$STATUS" = MISS ] || fail "Akses pertama $STATUS, seharusnya MISS";
        else [ "$STATUS" = HIT ] || fail "Akses kedua $STATUS, seharusnya HIT"; fi
        echo "PASS cache request=$I HTTP=200 X-Cache-Status=$STATUS"
    done
    cmp "$DIR/cache-1.html" "$DIR/cache-2.html" || fail 'Body cache tidak sama'
fi
if [ "$MODE" = rate ] || [ "$MODE" = all ]; then
    sleep 1
    I=1
    while [ "$I" -le 30 ]; do
        (curl_get -H "X-Test-Run: soal19-$TAG-rate" -D "$DIR/rate-$I.headers" -o "$DIR/rate-$I.body" -w '%{http_code}' "http://jujutsu.k46.com/api/soal19-$TAG-$I" > "$DIR/rate-$I.code" || echo ERROR > "$DIR/rate-$I.code") &
        I=$((I+1))
    done
    wait
    OK=0; REJECTED=0
    for F in "$DIR"/rate-*.code; do
        CODE=$(cat "$F")
        case "$CODE" in 200) OK=$((OK+1));; 429) REJECTED=$((REJECTED+1));; *) fail "Status burst tidak diharapkan: $CODE";; esac
    done
    [ "$OK" -gt 0 ] && [ "$REJECTED" -gt 0 ] || fail 'Butuh respons berhasil dan respons yang ditolak'
    grep -il '^X-Rate-Limit-Status: REJECTED' "$DIR"/rate-*.headers >/dev/null || fail 'Header REJECTED tidak ditemukan'
    echo "PASS rate client=$CLIENT total=30 HTTP200=$OK HTTP429=$REJECTED"
    echo 'Batas 10r/s memakai leaky bucket tanpa burst; bukan jatah 10 request serentak.'
fi
echo "PASS soal 19 mode=$MODE; bukti=$DIR"
