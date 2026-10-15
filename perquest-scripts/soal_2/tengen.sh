#!/bin/sh
# Soal 2
#   - tengen: isc-dhcp-server di 192.234.4.10. Network 4 = subnet lokal tanpa pool;
#     scope Network 2 dan 3 disiapkan (pool awal, dipersempit oleh soal 4 dan 5).

# Install isc-dhcp-server jika belum ada
if ! command -v dhcpd >/dev/null; then
    apt-get update && apt-get install -y isc-dhcp-server
fi

# DHCP server mendengarkan di eth0
cat > /etc/default/isc-dhcp-server <<'EOF'
INTERFACESv4="eth0"
INTERFACESv6=""
EOF

# Backup config lama, lalu tulis dhcpd.conf baru
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

# Validasi; kembalikan backup jika config salah
if ! dhcpd -4 -t -cf /etc/dhcp/dhcpd.conf; then
    cp /etc/dhcp/dhcpd.conf.bak /etc/dhcp/dhcpd.conf
    echo "ERR: config salah, dikembalikan"
    exit 1
fi

# Restart DHCP server
service isc-dhcp-server restart
sleep 1
service isc-dhcp-server status
