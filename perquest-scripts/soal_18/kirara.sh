#!/bin/sh
# Soal 18: verifikasi API cadangan kompatibel dan koneksi SELECT ke yaga.
# Node: kirara; file repo: perquest-scripts/soal_18/kirara.sh
set -eu
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
fail() { echo "FAIL: $*" >&2; exit 1; }
[ "$(hostname | tr '[:upper:]' '[:lower:]')" = kirara ] || fail "Hanya untuk kirara"
[ "$(id -u)" = 0 ] || fail "Jalankan sebagai root"
nginx -t
service nginx status
FPM=$(find /etc/init.d -maxdepth 1 -name 'php*-fpm' -type f | sort -V | tail -n 1)
[ -n "$FPM" ] || fail 'PHP-FPM belum tersedia dari soal 14'
service "${FPM##*/}" status
php -l /var/www/jarkom14/index.php
php -r '$c=json_decode(file_get_contents("/etc/jarkom14/db.json"),true,512,JSON_THROW_ON_ERROR); if(($c["trusted_geto"]??"")!=="192.234.4.2")exit(2); $p=new PDO("mysql:host=".$c["host"].";port=".$c["port"].";dbname=".$c["database"],$c["username"],$c["password"],[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION,PDO::ATTR_TIMEOUT=>4]); $p->query("SELECT client_ip,worker,method,path FROM request_logs LIMIT 0"); echo "PASS: kirara siap, trusted_geto benar, kolom log/database tersedia\n";'
