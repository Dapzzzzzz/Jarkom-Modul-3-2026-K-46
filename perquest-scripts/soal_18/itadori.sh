#!/bin/sh
# Soal 18: uji primary, backup saat gangguan, dan pemulihan dari Network 2.
# Node: itadori; file repo: perquest-scripts/soal_18/itadori.sh
set -eu
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
fail() { echo "FAIL: $*" >&2; exit 1; }
[ "$(hostname | tr '[:upper:]' '[:lower:]')" = itadori ] || fail "Hanya untuk itadori"
[ "$(id -u)" = 0 ] || fail "Jalankan sebagai root"
DEMO=0
if [ "${1:-}" = --demo ]; then DEMO=1; shift; fi
TEMP_IP=0; TEMP_ROUTE=0
cleanup() {
    [ "$TEMP_ROUTE" = 0 ] || ip route del default via 192.234.2.1 dev eth0
    [ "$TEMP_IP" = 0 ] || ip addr del 192.234.2.250/24 dev eth0
}
trap cleanup EXIT
trap 'exit 130' HUP INT TERM
if [ "$DEMO" = 1 ] && [ -z "$(ip -4 -o addr show eth0)" ]; then
    [ -z "$(ip route show default)" ] || fail 'IP kosong tetapi gateway ada; cek manual'
    arping -D -c 2 -w 3 -I eth0 192.234.2.250 || fail 'IP uji mungkin terpakai'
    ip addr add 192.234.2.250/24 dev eth0; TEMP_IP=1
    ip route add default via 192.234.2.1 dev eth0; TEMP_ROUTE=1
    echo 'IP uji 192.234.2.250; alamat dan route uji dihapus otomatis'
fi
CLIENT=$(ip -4 route get 192.234.1.4 | awk '{for(i=1;i<=NF;i++)if($i=="src"){print $(i+1);exit}}')
case "$CLIENT" in 192.234.2.*) ;; *) fail 'Client belum memiliki IP/gateway Network 2';; esac
command -v curl >/dev/null 2>&1 || fail 'curl belum tersedia'
curl_get() {
    if [ "$DEMO" = 1 ]; then
        curl --noproxy '*' --interface "$CLIENT" --resolve jujutsu.k46.com:80:192.234.1.4 --max-time 15 -sS "$@"
    else
        curl --noproxy '*' --interface "$CLIENT" --max-time 15 -sS "$@"
    fi
}

MODE=${1:-primary}
case "$MODE" in primary|backup|recovered) ;; *) fail 'Mode: [--demo] primary|backup|recovered';; esac
TAG=$(date +%s)-$$
DIR=/root/no18-verifikasi-$TAG-$MODE
mkdir -p "$DIR"
: > "$DIR/workers.txt"
for I in 1 2 3 4 5 6 7 8; do
    CODE=$(curl_get -D "$DIR/$I.headers" -o "$DIR/$I.json" -w '%{http_code}' "http://jujutsu.k46.com/api/soal18-$TAG-$MODE-$I")
    cat "$DIR/$I.json"
    [ "$CODE" = 200 ] || fail "HTTP=$CODE; failover tidak boleh menghasilkan 502"
    grep -q '"ok":true' "$DIR/$I.json" || fail 'Respons API tidak valid'
    grep -q "\"client_ip\":\"$CLIENT\"" "$DIR/$I.json" || fail 'IP asli soal 17 hilang'
    WORKER=$(sed -n 's/.*"worker":"\([^"]*\)".*/\1/p' "$DIR/$I.json")
    if [ "$MODE" = backup ]; then
        [ "$WORKER" = kirara ] || fail "Seharusnya kirara, mendapat $WORKER"
    else
        case "$WORKER" in nanami|todo) ;; *) fail "Primary seharusnya aktif, mendapat $WORKER";; esac
    fi
    echo "$WORKER" >> "$DIR/workers.txt"
    echo "PASS request=$I HTTP=$CODE phase=$MODE worker=$WORKER client_ip=$CLIENT"
    # Tetap cocok bila diverifikasi lagi setelah rate limit soal 19 aktif.
    sleep 0.15
done
sort "$DIR/workers.txt" | uniq -c
echo "PASS soal 18 phase=$MODE; bukti=$DIR"
