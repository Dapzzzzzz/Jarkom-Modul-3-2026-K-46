#!/bin/sh
# Soal 3 - jichi: DHCP relay. eth2 (Network 2) dan eth3 (Network 3) sisi client,
# eth4 sisi Data Center, menuju tengen 192.234.4.10.
# Simpan di /root/soal_3.sh lalu jalankan: sh /root/soal_3.sh
command -v dhcrelay >/dev/null || { apt-get update && apt-get install -y isc-dhcp-relay; }

cat > /etc/default/isc-dhcp-relay <<'EOF'
SERVERS="192.234.4.10"
INTERFACES=""
OPTIONS="-4 -id eth2 -id eth3 -iu eth4"
EOF

service isc-dhcp-relay restart
sleep 1
service isc-dhcp-relay status
ps -eo args | grep '[d]hcrelay'
ping -c 2 192.234.4.10

# Autostart: jalankan ulang saat node boot (/root/init.sh dieksekusi image saat boot).
[ -f /root/init.sh ] || echo '#!/bin/sh' > /root/init.sh
grep -qF 'service isc-dhcp-relay start >> /root/soal_3.log 2>&1' /root/init.sh || echo 'service isc-dhcp-relay start >> /root/soal_3.log 2>&1' >> /root/init.sh
chmod 755 /root/init.sh
