#!/bin/sh
# Paket FINAL 14-20. File node=gojo, soal=20.
# Verifikasi konfigurasi: --verify (alias cek); bantuan: --help.
# Client: --demo untuk HTTP tanpa ketergantungan DHCP/DNS; lihat PANDUAN-FINAL.md.
if [ "${1:-}" = --help ]; then
cat <<'FINAL_HELP'
SOAL 20 - NODE gojo
File ini khusus node gojo; simpan sebagai /root/soal_20.sh.
Panduan lengkap dan urutan uji: PANDUAN-FINAL.md pada paket ZIP.
Cek: --verify/cek. Baseline: --baseline. Pulihkan: --enforce/aktif. Bukti: --audit/bukti TAG.
FINAL_HELP
exit 0
fi
case "${1:-}" in
    --verify) shift; set -- cek "$@";;
    --audit) shift; set -- bukti "$@";;
    --logs) shift; set -- log "$@";;
    --baseline) shift; set -- baseline "$@";;
    --enforce) shift; set -- aktif "$@";;
esac
# Soal 20
#   - gojo: baseline API, aktifkan lagi rate limit, dan periksa access log.
#   - Jalankan setelah soal 19. Tidak membuat server/upstream baru.
#   - Simpan sebagai /root/soal_20.sh pada gojo.
#
# Verifikasi:
#   sh /root/soal_20.sh cek
#   sh /root/soal_20.sh bukti TAG    # setelah 3 benchmark selesai di Kusakabe
#   sh /root/soal_20.sh log TAG      # lihat log mentah untuk diagnosis
# Baseline: sh /root/soal_20.sh baseline
# WAJIB sesudahnya: sh /root/soal_20.sh aktif

set -eu
[ "$(hostname | tr '[:upper:]' '[:lower:]')" = gojo ] || { echo 'Jalankan pada gojo'; exit 1; }
MODE=${1:-cek}
LIMIT=/etc/nginx/snippets/soal19-enforcement.conf
LOG=/var/log/nginx/soal19-access.log
STATE=/root/no20
mkdir -p "$STATE"
[ -f "$LIMIT" ] || { echo 'Konfigurasi rate limit soal 19 belum tersedia'; exit 1; }

# Bukti baseline dan limited harus berasal dari TAG yang sama.
if [ "$MODE" = log ] || [ "$MODE" = bukti ]; then
    TAG=${2:-$(cat /root/no20/latest-tag 2>/dev/null || true)}
    printf '%s\n' "$TAG" | grep -Eq '^[A-Za-z0-9-]+$' || { echo 'Isi TAG benchmark'; exit 1; }
    printf '%s\n' "$TAG" > "$STATE/latest-tag"
    if [ "$MODE" = log ]; then grep -F "\"run\":\"$TAG-" "$LOG"; exit; fi
    awk -v tag="$TAG" '
    function value(k,t,p,key) {key="\"" k "\":\"";p=index($0,key);if(!p)return "";t=substr($0,p+length(key));return substr(t,1,index(t,"\"")-1)}
    index($0,"\"run\":\"" tag "-") {
        phase=value("run");phase=substr(phase,length(tag)+2)
        code=$0;sub(/^.*"status":/,"",code);sub(/,.*/,"",code);code+=0
        n[phase]++
        if(code==200)ok[phase]++
        if(code==429 && value("limit")=="REJECTED")reject[phase]++
        if(code>=500)errors[phase]++
        if(value("cache")=="HIT")hit[phase]++
        if(value("limit")=="REJECTED_DRY_RUN")dry[phase]++
    }
    END {
        split("web baseline limited",phases," ")
        for(i=1;i<=3;i++){p=phases[i];printf "%s: total=%d HTTP200=%d HTTP429=%d HTTP5xx=%d cacheHIT=%d calon_reject_dryrun=%d\n",p,n[p],ok[p],reject[p],errors[p],hit[p],dry[p]}
        if(n["web"]!=600 || ok["web"]!=600 || hit["web"]!=600 || n["baseline"]!=600 || ok["baseline"]!=600 || n["limited"]!=600 || ok["limited"]<1 || reject["limited"]<1 || ok["limited"]+reject["limited"]!=600)exit 1
    }' "$LOG"
    echo 'PASS: 600 log tiap fase cocok; 429 berasal dari rate limit, bukan error backend'
    exit
fi

case "$MODE" in
    cek)
        nginx -t
        service nginx status
        cat "$LIMIT"
        grep -qx 'limit_req_dry_run off;' "$LIMIT" || { echo 'Baseline masih aktif; jalankan mode aktif'; exit 1; }
        echo 'PASS: rate limit aktif'
        exit;;
    baseline|aktif) ;;
    *) echo 'Mode: cek | baseline | aktif | bukti TAG | log TAG'; exit 1;;
esac

# Backup dan validasi; hanya ubah mode pengujian limiter dari soal 19.
exec 9> "$STATE/simple-mode.lock"
flock -n 9 || { echo 'Perubahan mode lain sedang berjalan'; exit 1; }
if [ "$MODE" = aktif ] && [ -n "${2:-}" ]; then
    [ "$(cat "$STATE/simple-token" 2>/dev/null || true)" = "$2" ] || exit 0
fi
cp -p "$LIMIT" "$STATE/simple-mode.before"
if [ "$MODE" = baseline ]; then
    [ ! -f "$STATE/simple-token" ] || { echo 'Selesaikan baseline sebelumnya dengan mode aktif'; exit 1; }
    TOKEN=$(date +%s)-$$
    SELF=$(readlink -f "$0")
    printf '%s\n' "$TOKEN" > "$STATE/simple-token"
    # Pulihkan otomatis setelah 60 detik jika sesi pengujian terputus.
    nohup sh -c 'sleep 60; [ "$(cat /root/no20/simple-token 2>/dev/null)" = "$1" ] && sh "$2" aktif "$1"; exit 0' sh "$TOKEN" "$SELF" > "$STATE/simple-watchdog.log" 2>&1 < /dev/null 9>&- &
    printf 'limit_req_dry_run on;\n' > "$LIMIT"
else
    printf 'limit_req_dry_run off;\n' > "$LIMIT"
fi
if ! nginx -t || ! service nginx reload; then
    cp -p "$STATE/simple-mode.before" "$LIMIT"
    nginx -t && service nginx reload || true
    rm -f "$STATE/simple-token"
    echo 'FAIL: mode sebelumnya dikembalikan'; exit 1
fi
[ "$MODE" != aktif ] || rm -f "$STATE/simple-token"
cat "$LIMIT"
echo "PASS: mode $MODE"
