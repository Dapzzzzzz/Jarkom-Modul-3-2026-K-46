#!/bin/sh
# Soal 4
#   - tengen: dua pool Network 2 berdasarkan MAC (DHCP class).
#   - Pool 1 .2.10-.2.35 (itadori, fushiguro); Pool 2 .2.70-.2.95 (zenin, okkotsu); .2.36-.2.69 tidak dialokasikan.
#   - Config ini kumulatif: jalankan setelah soal 2.

# Backup config lama, lalu tulis dhcpd.conf baru
cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bak 2>/dev/null
cat > /etc/dhcp/dhcpd.conf <<'EOF'
authoritative;
ddns-update-style none;
default-lease-time 3600;
max-lease-time 7200;

class "divA-pool1" {
  match if substring(hardware, 1, 6) = 02:42:b1:2c:43:00
        or substring(hardware, 1, 6) = 02:42:40:6b:23:00;
}

class "divA-pool2" {
  match if substring(hardware, 1, 6) = 02:42:3b:3a:6b:00
        or substring(hardware, 1, 6) = 02:42:35:6c:75:00;
}

# Network 4: subnet lokal tengen, tanpa pool dinamis
subnet 192.234.4.0 netmask 255.255.255.0 {
}

# Network 2 (Divisi A)
subnet 192.234.2.0 netmask 255.255.255.0 {
  option routers 192.234.2.1;
  option broadcast-address 192.234.2.255;

  pool {
    allow members of "divA-pool1";
    range 192.234.2.10 192.234.2.35;
  }

  pool {
    allow members of "divA-pool2";
    range 192.234.2.70 192.234.2.95;
  }
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
