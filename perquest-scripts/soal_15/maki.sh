#!/bin/sh
# Soal 15
#   - maki: loop 40 request ke geto; hasil sehat nanami=30, todo=10.
#   - File repo: perquest-scripts/soal_15/maki.sh
[ "$(hostname | tr '[:upper:]' '[:lower:]')" = maki ] || { echo "Hanya untuk node maki" >&2; exit 1; }

# Soal 15, verifikasi 3: loop request dari node lokal Data Center (contoh maki).
# Tidak mengubah IP, route, konfigurasi worker, atau data lama.
set -eu
N=${1:-40}
case "$N" in ''|*[!0-9]*) echo 'Jumlah request harus bilangan positif'; exit 1;; esac
[ "$N" -gt 0 ] && [ $((N % 4)) = 0 ] || { echo 'Gunakan kelipatan 4, contoh 40'; exit 1; }
IP=$(ip -4 -o addr show eth0 | awk '{split($4,a,"/");print a[1];exit}')
PREFIX=$(printf '%s\n' "$IP" | awk -F. '{print $1"."$2}')
case "$IP" in "$PREFIX".4.*) ;; *) echo 'Jalankan dari node Network 4 / Data Center'; exit 1;; esac
command -v curl >/dev/null || { echo 'curl belum tersedia'; exit 1; }
GETO=$PREFIX.4.2
TAG=$(date +%s)-$$
DIR=/root/no15-verifikasi-$TAG
mkdir -p "$DIR"
: > "$DIR/workers.txt"
I=1
while [ "$I" -le "$N" ]; do
    CODE=$(curl --noproxy '*' --max-time 20 -sS -o "$DIR/last-response.json" -w '%{http_code}' "http://$GETO/api/soal15-$TAG-$I")
    [ "$CODE" = 200 ] || { cat "$DIR/last-response.json"; echo "FAIL request=$I HTTP=$CODE"; exit 1; }
    grep -q '"ok":true' "$DIR/last-response.json" || { cat "$DIR/last-response.json"; echo 'FAIL API tidak berhasil mencatat log'; exit 1; }
    WORKER=$(sed -n 's/.*"worker":"\([^"]*\)".*/\1/p' "$DIR/last-response.json")
    LOGID=$(sed -n 's/.*"log_id":"\([^"]*\)".*/\1/p' "$DIR/last-response.json")
    case "$WORKER" in nanami|todo) ;; *) echo "FAIL worker tidak sesuai: $WORKER"; exit 1;; esac
    printf '%s\n' "$WORKER" >> "$DIR/workers.txt"
    printf '%s\n' "request=$I HTTP=$CODE worker=$WORKER log_id=$LOGID" | tee -a "$DIR/requests.log"
    I=$((I + 1))
done
NANAMI=$(grep -c '^nanami$' "$DIR/workers.txt" || true)
TODO=$(grep -c '^todo$' "$DIR/workers.txt" || true)
echo "SUMBER: $(hostname) ($IP) -> geto $GETO:80"
echo "TOTAL=$N NANAMI=$NANAMI TODO=$TODO"
awk -v a="$NANAMI" -v b="$TODO" -v n="$N" 'BEGIN {printf "Persentase nanami=%.0f%% todo=%.0f%%\n",100*a/n,100*b/n;if(b>0)printf "Rasio nanami:todo=%.2f:1\n",a/b}'
[ "$NANAMI" -eq $((N * 3 / 4)) ] && [ "$TODO" -eq $((N / 4)) ] || { echo "FAIL: rasio belum 3:1; cek kesehatan backend dan request lain yang bersamaan. Bukti: $DIR"; exit 1; }
echo "PASS: Weighted Round Robin 3:1; bukti=$DIR"
