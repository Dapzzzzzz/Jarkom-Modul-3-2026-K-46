#!/bin/sh
# Soal 10 - jichi: DHCP Relay autostart dan bertahan setelah restart node.
# Simpan di /root/soal_10.sh. Langkah: sh /root/soal_10.sh  -> restart node  -> sh /root/soal_10.sh
[ -f /root/init.sh ] || echo '#!/bin/sh' > /root/init.sh
grep -qF 'service isc-dhcp-relay start' /root/init.sh || echo 'service isc-dhcp-relay start >> /root/soal_3.log 2>&1' >> /root/init.sh
chmod 755 /root/init.sh
echo "== init.sh =="; cat /root/init.sh

echo "== Status =="
service isc-dhcp-relay status
ps -eo args | grep '[d]hcrelay'
ip -4 -br addr
sysctl net.ipv4.ip_forward
iptables -t nat -S POSTROUTING
ping -c 2 192.234.4.10
