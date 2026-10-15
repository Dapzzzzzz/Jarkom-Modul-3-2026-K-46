#!/bin/sh
# Soal 10 - tengen: DHCP Server autostart dan bertahan setelah restart node.
# Simpan di /root/soal_10.sh. Langkah: sh /root/soal_10.sh  -> restart node  -> sh /root/soal_10.sh
[ -f /root/init.sh ] || echo '#!/bin/sh' > /root/init.sh
grep -qF 'service isc-dhcp-server start' /root/init.sh || echo 'service isc-dhcp-server start >> /root/soal_2.log 2>&1' >> /root/init.sh
chmod 755 /root/init.sh
echo "== init.sh =="; cat /root/init.sh

echo "== Status =="
service isc-dhcp-server status
ip -4 -br addr show eth0
ip route | grep default
dhcpd -4 -t -cf /etc/dhcp/dhcpd.conf && echo "PASS: config valid"
echo "== Kebijakan =="
grep -E 'range|lease-time|fixed-address|allow members' /etc/dhcp/dhcpd.conf
