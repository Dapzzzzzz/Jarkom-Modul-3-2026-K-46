#!/bin/sh
# Soal 16
#   - itadori: verifikasi dua domain lewat DNS client; mode all/frontend/api; IP tidak diubah.
#   - File repo: perquest-scripts/soal_16/itadori.sh
[ "$(hostname | tr '[:upper:]' '[:lower:]')" = itadori ] || { echo "Hanya untuk node itadori" >&2; exit 1; }

# Soal 16 — uji dari client Divisi A/B. Mode: all (default), frontend, api.
set -eu
USE_DNS=${USE_DNS:-1}
export USE_DNS
MODE=${1:-all}
case "$MODE" in all|frontend|api) ;; *) echo 'Mode: all, frontend, api'; exit 1;; esac
P=${PREFIX:-192.234}
NODE=$(hostname | tr '[:upper:]' '[:lower:]')
case "$NODE" in
    itadori|fushiguro|zenin|okkotsu) NET=2;;
    ino|kusakabe|miwa|kugisaki) NET=3;;
    *) echo 'Jalankan dari client Divisi A/B'; exit 1;;
esac
ip -4 addr show dev eth0 | grep -q 'inet ' || { echo 'Client belum memiliki IPv4; periksa soal DHCP terlebih dahulu'; exit 1; }
ip route show default | grep -q '^default' || { echo 'Default gateway client belum tersedia'; exit 1; }
command -v curl >/dev/null || { echo 'curl belum tersedia'; exit 1; }
TAG=$(date +%s)-$$
DIR=/root/no16-verifikasi-$TAG
mkdir -p "$DIR"
: > "$DIR/frontend.txt"; : > "$DIR/api.txt"
fetch() {
    DOMAIN=$1; URLPATH=$2
    if [ "${USE_DNS:-0}" = 1 ]; then
        CODE=$(curl --noproxy '*' --max-time 15 -sS -D "$DIR/headers.txt" -o "$DIR/body.txt" -w '%{http_code}' "http://$DOMAIN$URLPATH")
    else
        CODE=$(curl --noproxy '*' --resolve "$DOMAIN:80:$P.1.4" --max-time 15 -sS -D "$DIR/headers.txt" -o "$DIR/body.txt" -w '%{http_code}' "http://$DOMAIN$URLPATH")
    fi
    [ "$CODE" = 200 ] || { cat "$DIR/body.txt"; echo "FAIL $DOMAIN$URLPATH HTTP=$CODE"; exit 1; }
}
echo "SUMBER: $NODE Network $NET -> gojo $P.1.4:80"
if [ "${USE_DNS:-0}" = 1 ]; then echo 'RESOLUSI: DNS client'; else echo 'RESOLUSI: curl --resolve, tanpa mengubah DNS/hosts client'; fi
if [ "$MODE" = all ] || [ "$MODE" = frontend ]; then
    for D in jujutsu.k46.com www.jujutsu.k46.com; do
        for I in 1 2 3 4; do
            fetch "$D" /
            grep -iq '^X-Gojo-Route: frontend' "$DIR/headers.txt" || { echo 'FAIL: route bukan frontend'; exit 1; }
            WORKER=$(sed -n 's/.*<strong>\([^<]*\)<\/strong>.*/\1/p' "$DIR/body.txt")
            case "$WORKER" in maki|panda) ;; *) echo "FAIL worker frontend=$WORKER"; exit 1;; esac
            echo "$WORKER" >> "$DIR/frontend.txt"
            echo "FRONTEND host=$D path=/ HTTP=200 worker=$WORKER" | tee -a "$DIR/requests.log"
        done
    done
    MAKI=$(grep -c '^maki$' "$DIR/frontend.txt" || true)
    PANDA=$(grep -c '^panda$' "$DIR/frontend.txt" || true)
    echo "FRONTEND TOTAL=8 MAKI=$MAKI PANDA=$PANDA"
    [ "$MAKI" = 4 ] && [ "$PANDA" = 4 ] || { echo 'FAIL: distribusi frontend belum 1:1; hindari request lain bersamaan'; exit 1; }
fi
if [ "$MODE" = all ] || [ "$MODE" = api ]; then
    for D in jujutsu.k46.com www.jujutsu.k46.com; do
        for PATHNAME in /api /api/ "/api/soal16-$TAG?source=$NODE" "/api/soal16-$TAG/end"; do
            fetch "$D" "$PATHNAME"
            grep -iq '^X-Gojo-Route: api' "$DIR/headers.txt" || { echo 'FAIL: route bukan api'; exit 1; }
            grep -iq "^X-Gojo-Upstream: $P.4.2:80" "$DIR/headers.txt" || { echo 'FAIL: API tidak melewati geto'; exit 1; }
            grep -q '"ok":true' "$DIR/body.txt" || { cat "$DIR/body.txt"; exit 1; }
            WORKER=$(sed -n 's/.*"worker":"\([^"]*\)".*/\1/p' "$DIR/body.txt")
            LOGID=$(sed -n 's/.*"log_id":"\([^"]*\)".*/\1/p' "$DIR/body.txt")
            case "$WORKER" in nanami|todo) ;; *) echo "FAIL worker api=$WORKER"; exit 1;; esac
            echo "$WORKER" >> "$DIR/api.txt"
            echo "API host=$D path=$PATHNAME HTTP=200 via=geto worker=$WORKER log_id=$LOGID" | tee -a "$DIR/requests.log"
        done
    done
    NANAMI=$(grep -c '^nanami$' "$DIR/api.txt" || true)
    TODO=$(grep -c '^todo$' "$DIR/api.txt" || true)
    echo "API TOTAL=8 NANAMI=$NANAMI TODO=$TODO (bobot geto dari soal 15)"
    [ "$NANAMI" = 6 ] && [ "$TODO" = 2 ] || { echo 'FAIL: distribusi API belum 3:1; periksa geto/backend dan request lain'; exit 1; }
fi
if [ "$MODE" = all ]; then
    for D in jujutsu.k46.com www.jujutsu.k46.com; do
        fetch "$D" /apix
        grep -iq '^X-Gojo-Route: frontend' "$DIR/headers.txt" || { echo 'FAIL: /apix salah diarahkan ke API'; exit 1; }
        echo "BOUNDARY host=$D path=/apix HTTP=200 route=frontend" | tee -a "$DIR/requests.log"
    done
fi
echo "PASS: $NODE nomor 16 mode=$MODE; bukti=$DIR"
