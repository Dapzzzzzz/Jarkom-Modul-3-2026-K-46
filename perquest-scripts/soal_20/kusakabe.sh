#!/bin/sh
# Paket FINAL 14-20. File node=kusakabe, soal=20.
# Verifikasi konfigurasi: --verify (alias cek); bantuan: --help.
# Client: --demo untuk HTTP tanpa ketergantungan DHCP/DNS; lihat PANDUAN-FINAL.md.
if [ "${1:-}" = --help ]; then
cat <<'FINAL_HELP'
SOAL 20 - NODE kusakabe
File ini khusus node kusakabe; simpan sebagai /root/soal_20.sh.
Panduan lengkap dan urutan uji: PANDUAN-FINAL.md pada paket ZIP.
Benchmark: --demo web TAG, --demo baseline TAG, --demo limited TAG; ringkasan --verify TAG.
Gojo --baseline sebelum API baseline; WAJIB --enforce sesudahnya.
FINAL_HELP
exit 0
fi
case "${1:-}" in
    --demo) shift; set -- demo "$@";;
    --verify) shift; set -- cek "$@";;
esac
# Soal 20
#   - kusakabe: Apache Benchmark 600 request, concurrency 30, catat RPS/latensi/error.
#   - Jalankan setelah soal 19; ab bukan layanan Apache HTTP server.
#   - Simpan sebagai /root/soal_20.sh pada kusakabe.
#
# Urutan uji (gunakan satu TAG yang sama, contoh demo20-1):
#   sh /root/soal_20.sh web demo20-1
#   [gojo] sh /root/soal_20.sh baseline
#   sh /root/soal_20.sh baseline demo20-1
#   [gojo] sh /root/soal_20.sh aktif
#   sleep 1
#   sh /root/soal_20.sh limited demo20-1
# Verifikasi: sh /root/soal_20.sh cek demo20-1
# Lanjut di gojo: sh /root/soal_20.sh bukti demo20-1
# Bila client belum memiliki IP/DNS, tambahkan kata demo sebelum mode benchmark:
#   sh /root/soal_20.sh demo web demo20-1
# Semua perubahan jaringan mode demo bersifat sementara dan dibersihkan saat exit.

set -eu
[ "$(hostname | tr '[:upper:]' '[:lower:]')" = kusakabe ] || { echo 'Jalankan pada kusakabe'; exit 1; }
DEMO=0
if [ "${1:-}" = demo ]; then DEMO=1; shift; fi
MODE=${1:-cek}
TAG=${2:-$(cat /root/no20/latest-tag 2>/dev/null || true)}
printf '%s\n' "$TAG" | grep -Eq '^[A-Za-z0-9-]+$' || { echo 'Isi TAG, contoh: sh /root/soal_20.sh web demo20-1'; exit 1; }
STATE=/root/no20
mkdir -p "$STATE"

# Bukti ringkas dari hasil ab yang disimpan; tidak menjalankan benchmark lagi.
if [ "$MODE" = cek ]; then
    for P in web baseline limited; do
        F=$STATE/$TAG-$P-ab.txt
        [ -f "$F" ] || { echo "Hasil $P belum ada"; exit 1; }
        awk -v p="$P" '
        /^Complete requests:/{complete=$3}
        /^Failed requests:/{failed=$3}
        /^Non-2xx responses:/{non2xx=$3}
        /^Requests per second:/{rps=$4}
        /^Time per request:/ && !/across all/{mean=$4}
        /^[[:space:]]*95%/{p95=$2}
        END {
            printf "%s: complete=%d failed=%d non2xx=%d RPS=%s mean_ms=%s p95_ms=%s\n",p,complete,failed,non2xx,rps,mean,p95
            if(complete!=600 || failed!=0 || (p!="limited" && non2xx!=0) || (p=="limited" && (non2xx<1 || non2xx>=600)))exit 1
        }' "$F"
    done
    echo "PASS output ab; cocokkan dengan log gojo: sh /root/soal_20.sh bukti $TAG"
    exit
fi
case "$MODE" in web|baseline|limited) ;; *) echo 'Mode: [demo] web|baseline|limited|cek TAG'; exit 1;; esac
command -v ab >/dev/null 2>&1 || { echo 'Pasang ab dahulu: apk add apache2-utils (memerlukan koneksi internet/DNS)'; exit 1; }
DIR=$(mktemp -d "$STATE/run-$TAG-$MODE-XXXXXX")
IP_ADDED=0; ROUTE_ADDED=0; HOSTS_CHANGED=0
cleanup() {
    [ "$HOSTS_CHANGED" = 0 ] || cat "$DIR/hosts.before" > /etc/hosts
    [ "$ROUTE_ADDED" = 0 ] || ip route del default via 192.234.3.1 dev eth0
    [ "$IP_ADDED" = 0 ] || ip addr del 192.234.3.250/24 dev eth0
}
trap cleanup EXIT
trap 'exit 130' HUP INT TERM

# Mode demo hanya dibutuhkan bila prasyarat jaringan/DNS belum tersedia.
if [ "$DEMO" = 1 ]; then
    if [ -z "$(ip -4 -o addr show eth0)" ]; then
        [ -z "$(ip route show default)" ] || { echo 'Periksa IP/gateway client dahulu'; exit 1; }
        arping -D -c 2 -w 3 -I eth0 192.234.3.250 || { echo 'IP uji mungkin sudah digunakan'; exit 1; }
        ip addr add 192.234.3.250/24 dev eth0; IP_ADDED=1
        ip route add default via 192.234.3.1 dev eth0; ROUTE_ADDED=1
    fi
    cp -p /etc/hosts "$DIR/hosts.before"
    HOSTS_CHANGED=1
    awk '{if($0~/^[[:space:]]*#/) {print;next} line=$1; for(i=2;i<=NF;i++)if(tolower($i)!="jujutsu.k46.com" && tolower($i)!="www.jujutsu.k46.com")line=line" "$i; if(NF==0 || NF==1 || line!=$1)print line}' "$DIR/hosts.before" > "$DIR/hosts.demo"
    printf '\n192.234.1.4 jujutsu.k46.com www.jujutsu.k46.com\n' >> "$DIR/hosts.demo"
    cat "$DIR/hosts.demo" > /etc/hosts
    echo 'DEMO: hosts/IP/route sementara; DNS tidak diuji'
fi
CLIENT=$(ip -4 route get 192.234.1.4 | awk '{for(i=1;i<=NF;i++)if($i=="src"){print $(i+1);exit}}')
case "$CLIENT" in 192.234.3.*) ;; *) echo 'Kusakabe belum punya IP/gateway Network 3'; exit 1;; esac

URL=http://jujutsu.k46.com/
if [ "$MODE" = web ]; then
    curl --noproxy '*' --interface "$CLIENT" --max-time 10 -fsS "$URL" > "$DIR/warmup.html"
else
    URL=http://jujutsu.k46.com/api/soal20-$TAG
fi
echo "Benchmark $MODE, sumber=$CLIENT, URL=$URL, TAG=$TAG"
# -l menghindari gagal palsu karena panjang JSON berubah; timeout membatasi uji.
RC=0
timeout 45 ab -n 600 -c 30 -l -s 5 -r -B "$CLIENT" -H "X-Test-Run: $TAG-$MODE" "$URL" > "$DIR/ab.txt" 2>&1 || RC=$?
cat "$DIR/ab.txt"
[ "$RC" = 0 ] || { echo "FAIL ab exit=$RC; hasil belum lengkap"; exit 1; }
grep -Eq '^Complete requests:[[:space:]]+600$' "$DIR/ab.txt" || { echo 'Request belum 600'; exit 1; }
cp "$DIR/ab.txt" "$STATE/$TAG-$MODE-ab.txt"
printf '%s\n' "$TAG" > "$STATE/latest-tag"
echo "Hasil tersimpan: $STATE/$TAG-$MODE-ab.txt"
echo 'Failed requests=0 tidak menjamin semua HTTP200; periksa Non-2xx dan log gojo.'
