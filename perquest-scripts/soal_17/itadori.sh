#!/bin/sh
# Soal 17
#   - itadori: verifikasi IP asli/header palsu; normal lewat DNS, --demo memakai resolve/IP uji sementara.
#   - File repo: perquest-scripts/soal_17/itadori.sh
set -eu
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
fail() { echo "FAIL: $*" >&2; exit 1; }
[ "$(hostname | tr '[:upper:]' '[:lower:]')" = itadori ] || fail "Hanya untuk itadori"
# Empat request berurutan. Mode normal tidak mengubah jaringan.
# --demo: bila belum ada IPv4, tambahkan IP/route uji sementara dan hapus saat selesai.
command -v curl >/dev/null 2>&1 || fail 'curl belum tersedia'
MODE=${1:-normal}
case "$MODE" in normal|--demo) ;; *) fail 'Mode: normal atau --demo';; esac
USE_DNS=${USE_DNS:-1}
case "$USE_DNS" in 0|1) ;; *) fail 'USE_DNS harus 0 atau 1';; esac
NODE=itadori
TEMP_IP=0; TEMP_ROUTE=0
cleanup() {
    [ "$TEMP_ROUTE" = 0 ] || ip route del default via 192.234.2.1 dev eth0
    [ "$TEMP_IP" = 0 ] || ip addr del 192.234.2.250/24 dev eth0
}
trap cleanup EXIT
trap 'exit 130' INT TERM
if [ "$MODE" = --demo ]; then
    USE_DNS=0
    if [ -z "$(ip -4 -o addr show dev eth0)" ]; then
        [ -z "$(ip route show default)" ] || fail 'Tidak ada IP tetapi default route sudah ada; periksa manual'
        command -v arping >/dev/null 2>&1 || fail 'arping diperlukan untuk cek konflik IP uji'
        arping -D -c 2 -w 3 -I eth0 192.234.2.250 || fail 'IP uji mungkin sudah dipakai; tidak ditambahkan'
        ip addr add 192.234.2.250/24 dev eth0; TEMP_IP=1
        ip route add default via 192.234.2.1 dev eth0; TEMP_ROUTE=1
        echo 'IP UJI SEMENTARA: 192.234.2.250; IP/route dihapus otomatis setelah tes'
    fi
fi
EXPECTED=$(ip -4 route get 192.234.1.4 | awk '{for(i=1;i<=NF;i++)if($i=="src"){print $(i+1);exit}}')
case "$EXPECTED" in 192.234.2.*) ;; *) fail 'IP sumber harus dari Network 2; cek DHCP/routing dahulu';; esac
ip -4 -o addr show | awk '{split($4,a,"/");print a[1]}' | grep -qx "$EXPECTED" || fail 'IP sumber bukan alamat lokal'
TAG=$(date +%s)-$NODE-$$
DIR=/root/no17-verifikasi-$TAG
mkdir -p "$DIR"
printf 'tag=%s\nnode=%s\nexpected_client_ip=%s\n' "$TAG" "$NODE" "$EXPECTED" > "$DIR/info.txt"
if [ "$USE_DNS" = 1 ]; then echo 'RESOLUSI: DNS client'; else echo 'RESOLUSI: curl --resolve, DNS tidak diuji'; fi
I=0
for DOMAIN in jujutsu.k46.com www.jujutsu.k46.com; do
    for TEST in normal spoof; do
        I=$((I+1))
        URI=/api/soal17-$TAG/$I-$TEST
        # --interface mengikat IP sumber yang diuji, tanpa menambahkan alamat baru.
        set -- curl --noproxy '*' --interface "$EXPECTED" --max-time 15 -sS
        if [ "$USE_DNS" = 0 ]; then set -- "$@" --resolve "$DOMAIN:80:192.234.1.4"; fi
        if [ "$TEST" = spoof ]; then
            CODE=$("$@" \
                -H 'X-Real-IP: 203.0.113.123' \
                -H 'X-Forwarded-For: 203.0.113.123, 198.51.100.77' \
                -D "$DIR/$I.headers" -o "$DIR/$I.json" -w '%{http_code}' "http://$DOMAIN$URI")
        else
            CODE=$("$@" \
                -D "$DIR/$I.headers" -o "$DIR/$I.json" -w '%{http_code}' "http://$DOMAIN$URI")
        fi
        cat "$DIR/$I.json"
        [ "$CODE" = 200 ] || fail "HTTP=$CODE; bila database_log_failed, periksa layanan/database yaga"
        grep -q '"ok":true' "$DIR/$I.json" || fail 'API tidak menyatakan log berhasil'
        ACTUAL=$(sed -n 's/.*"client_ip":"\([^"]*\)".*/\1/p' "$DIR/$I.json")
        WORKER=$(sed -n 's/.*"worker":"\([^"]*\)".*/\1/p' "$DIR/$I.json")
        LOG_ID=$(sed -n 's/.*"log_id":"\([0-9]*\)".*/\1/p' "$DIR/$I.json")
        [ "$ACTUAL" = "$EXPECTED" ] || fail "client_ip=$ACTUAL, seharusnya $EXPECTED; header palsu harus diabaikan"
        case "$WORKER" in nanami|todo) ;; *) fail "Worker tidak sesuai soal 15: $WORKER";; esac
        [ -n "$LOG_ID" ] || fail 'log_id tidak ada'
        grep -iq '^X-Gojo-Route: api' "$DIR/$I.headers" || fail 'Tidak melewati route API gojo'
        grep -iq '^X-Gojo-Upstream: 192\.234\.4\.2:80' "$DIR/$I.headers" || fail 'Tidak melewati geto'
        printf '%s\t%s\t%s\t%s\t%s\n' "$LOG_ID" "$EXPECTED" "$WORKER" "$DOMAIN" "$URI" >> "$DIR/expected.tsv"
        echo "PASS request=$I test=$TEST worker=$WORKER client_ip=$ACTUAL log_id=$LOG_ID"
    done
done
echo "PASS respons API $NODE: IP asli tetap $EXPECTED, termasuk ketika header dipalsukan"
echo "Bukti lokal: $DIR"
echo "Lanjutkan pada yaga (salin TAG dan IP dari hasil ini):"
echo "sh /root/soal_17.sh $TAG $EXPECTED"
