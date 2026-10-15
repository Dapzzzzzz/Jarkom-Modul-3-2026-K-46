#!/bin/sh
# Soal 2 - tengen: isc-dhcp-server di 192.234.4.10. Network 4 = subnet lokal tanpa pool;
# scope Network 2 dan 3 disiapkan (pool awal, dipersempit oleh soal 4 dan 5).
# Simpan di /root/soal_2.sh lalu jalankan: sh /root/soal_2.sh

command -v dhcpd >/dev/null || { apt-get update && apt-get install -y isc-dhcp-server; }

cat > /etc/default/isc-dhcp-server <<'EOF'
INTERFACESv4="eth0"
INTERFACESv6=""
EOF

cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bak 2>/dev/null
cat > /etc/dhcp/dhcpd.conf <<'EOF'
authoritative;
ddns-update-style none;
default-lease-time 3600;
max-lease-time 7200;

# Network 4: subnet lokal tengen, tanpa pool dinamis
subnet 192.234.4.0 netmask 255.255.255.0 {
}

# Network 2 (Divisi A)
subnet 192.234.2.0 netmask 255.255.255.0 {
  option routers 192.234.2.1;
  option broadcast-address 192.234.2.255;
  range 192.234.2.10 192.234.2.35;
}

# Network 3 (Divisi B)
subnet 192.234.3.0 netmask 255.255.255.0 {
  option routers 192.234.3.1;
  option broadcast-address 192.234.3.255;
  range 192.234.3.10 192.234.3.89;
}
EOF

# Validasi, lalu restart
dhcpd -4 -t -cf /etc/dhcp/dhcpd.conf || { cp /etc/dhcp/dhcpd.conf.bak /etc/dhcp/dhcpd.conf; echo "Config salah, dikembalikan"; exit 1; }
service isc-dhcp-server restart
sleep 1
service isc-dhcp-server status

# Autostart: jalankan ulang saat node boot (/root/init.sh dieksekusi image saat boot).
[ -f /root/init.sh ] || echo '#!/bin/sh' > /root/init.sh
grep -qF 'service isc-dhcp-server start >> /root/soal_2.log 2>&1' /root/init.sh || echo 'service isc-dhcp-server start >> /root/soal_2.log 2>&1' >> /root/init.sh
chmod 755 /root/init.sh
