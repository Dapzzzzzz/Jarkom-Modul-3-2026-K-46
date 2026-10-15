#!/bin/sh
# Soal 10
#   - tengen: DHCP Server autostart dan bertahan setelah restart node.
#   - Langkah: sh /root/soal_10.sh -> restart node -> sh /root/soal_10.sh

# Autostart: tambahkan DHCP server ke /root/init.sh jika belum ada
if [ ! -f /root/init.sh ]; then
    echo '#!/bin/sh' > /root/init.sh
fi
if ! grep -qF 'service isc-dhcp-server start' /root/init.sh; then
    echo 'service isc-dhcp-server start >> /root/soal_2.log 2>&1' >> /root/init.sh
fi
chmod 755 /root/init.sh

echo "== init.sh =="
cat /root/init.sh

echo "== Status =="
service isc-dhcp-server status
ip -4 -br addr show eth0
ip route | grep default

# Cek sintaks dhcpd.conf
if dhcpd -4 -t -cf /etc/dhcp/dhcpd.conf; then
    echo "OK: config valid"
else
    echo "ERR: config tidak valid"
fi

echo "== Kebijakan =="
grep -E 'range|lease-time|fixed-address|allow members' /etc/dhcp/dhcpd.conf
