#!/bin/sh
# Soal 14
#   - kusakabe: verifikasi akses langsung 403 dan akses melalui proxy 200; tidak mengubah IP/DNS.
#   - File repo: perquest-scripts/soal_14/kusakabe.sh
[ "$(hostname | tr '[:upper:]' '[:lower:]')" = kusakabe ] || { echo "Hanya untuk node kusakabe" >&2; exit 1; }

# Verifikasi saja: membutuhkan IPv4/gateway yang tersedia; tidak menambah IP sementara.
set -eu
P=${PREFIX:-192.234}
NODE=$(hostname | tr '[:upper:]' '[:lower:]')
case "$NODE" in itadori) NET=2;; kusakabe) NET=3;; *) echo 'Jalankan pada Itadori atau Kusakabe'; exit 1;; esac
ip -4 addr show dev eth0 | grep -q 'inet ' || { echo 'Client belum memiliki IPv4; periksa soal DHCP terlebih dahulu'; exit 1; }
ip route show default | grep -q '^default' || { echo 'Default gateway client belum tersedia'; exit 1; }
command -v curl >/dev/null || { echo 'curl belum ada: apk add --no-cache curl'; exit 1; }
PROXY_PORT=${PROXY_PORT:-80}
case "$PROXY_PORT" in 80|8080) ;; *) echo 'Gunakan PROXY_PORT=80 atau 8080'; exit 1;; esac
TAG=$(date +%s)-$$
BODY=$(mktemp /tmp/soal14-body.XXXXXX)
trap 'rm -f "$BODY"' EXIT
trap 'exit 130' INT TERM
for LAST in 3 4 5 6 7; do
  CODE=$(curl --noproxy '*' --max-time 8 -sS -o "$BODY" -w '%{http_code}' "http://$P.4.$LAST/")
  echo "Akses langsung worker $P.4.$LAST -> HTTP $CODE"
  [ "$CODE" = 403 ] || { echo 'FAIL: akses langsung seharusnya 403'; exit 1; }
done
for N in 1 2 3 4; do
  CODE=$(curl --noproxy '*' --resolve "jujutsu.k46.com:$PROXY_PORT:$P.1.4" --max-time 10 -sS -o "$BODY" -w '%{http_code}' http://jujutsu.k46.com:$PROXY_PORT/)
  [ "$CODE" = 200 ] && grep -Eq 'maki|panda' "$BODY" || { cat "$BODY"; echo "FAIL frontend HTTP $CODE"; exit 1; }
  echo "Frontend proxy HTTP $CODE: $(cat "$BODY")"
done
for N in 1 2 3 4 5 6; do
  CODE=$(curl --noproxy '*' --resolve "jujutsu.k46.com:$PROXY_PORT:$P.1.4" --max-time 10 -sS -o "$BODY" -w '%{http_code}' "http://jujutsu.k46.com:$PROXY_PORT/api/demo-no14-$TAG-$N")
  [ "$CODE" = 200 ] && grep -q '"ok":true' "$BODY" || { cat "$BODY"; echo "FAIL API HTTP $CODE"; exit 1; }
  echo "API proxy HTTP $CODE: $(cat "$BODY")"
done
echo "PASS: $NODE nomor 14; database path=/api/demo-no14-$TAG-*"
