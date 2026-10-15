#!/bin/sh
# Soal 14
#   - geto: proxy demo opsional port 8080; jalur utama ada di nomor 15-16.
#   - File repo: perquest-scripts/soal_14/geto.sh
[ "$(hostname | tr '[:upper:]' '[:lower:]')" = geto ] || { echo "Hanya untuk node geto" >&2; exit 1; }

# Jalur proxy demo nomor 14 pada port 8080; nomor 15-16 tetap terpisah.
set -eu
NODE=$(hostname | tr '[:upper:]' '[:lower:]')
IP=$(ip -4 -o addr show dev eth0 | awk '{split($4,a,"/"); print a[1]; exit}')
P=$(echo "$IP" | awk -F. '{print $1"."$2}')
mkdir -p /root/no14
if ! command -v nginx >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y nginx curl
fi
cat > /etc/nginx/conf.d/no14-demo.conf <<'CONF'
upstream no14_api {
    zone no14_api 64k;
    server __P__.4.5:80;
    server __P__.4.6:80;
    server __P__.4.7:80;
}
server {
    listen 8080;
    server_name api.k46.com jujutsu.k46.com;
    location / {
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP "";
        proxy_set_header X-Forwarded-For "";
        proxy_pass http://no14_api;
    }
}
CONF
sed -i "s/__P__/$P/g" /etc/nginx/conf.d/no14-demo.conf
nginx -t
if service nginx status >/dev/null 2>&1; then service nginx reload; else service nginx start; fi
SELF=$(readlink -f "$0")
[ "$SELF" = /root/no14-proxy.sh ] || cp "$SELF" /root/no14-proxy.sh
chmod 700 /root/no14-proxy.sh
if ! grep -qF '# JARKOM-NO14-PROXY-DEMO' /root/init.sh; then
  printf '\nsh /root/no14-proxy.sh >> /root/no14-proxy.log 2>&1 # JARKOM-NO14-PROXY-DEMO\n' >> /root/init.sh
fi
echo "PROXY_DEMO_OK $NODE port=8080"
