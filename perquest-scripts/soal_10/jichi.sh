#!/bin/sh
# Soal 10
#   - jichi: DHCP Relay autostart dan bertahan setelah restart node.
#   - Langkah: sh /root/soal_10.sh -> restart node -> sh /root/soal_10.sh

# Autostart: tambahkan relay ke /root/init.sh jika belum ada
if [ ! -f /root/init.sh ]; then
    echo '#!/bin/sh' > /root/init.sh
fi
if ! grep -qF 'service isc-dhcp-relay start' /root/init.sh; then
    echo 'service isc-dhcp-relay start >> /root/soal_3.log 2>&1' >> /root/init.sh
fi
chmod 755 /root/init.sh

echo "== init.sh =="
cat /root/init.sh

echo "== Status =="
service isc-dhcp-relay status
ps -eo args | grep '[d]hcrelay'
ip -4 -br addr
sysctl net.ipv4.ip_forward
iptables -t nat -S POSTROUTING
ping -c 2 192.234.4.10
