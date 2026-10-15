#!/bin/sh
# Soal 6
#   - tengen: static lease kugisaki (MAC 02:42:6b:21:47:00) -> 192.234.3.99, di luar pool dinamis.

cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bak 2>/dev/null
cat > /etc/dhcp/dhcpd.conf <<'EOF'
authoritative;
ddns-update-style none;
default-lease-time 3600;
max-lease-time 7200;

option domain-name-servers 192.234.1.2, 192.234.1.3;
option domain-name "K46.com";
option domain-search "K46.com";

class "divA-pool1" {
  match if substring(hardware, 1, 6) = 02:42:b1:2c:43:00
        or substring(hardware, 1, 6) = 02:42:40:6b:23:00;
}

class "divA-pool2" {
  match if substring(hardware, 1, 6) = 02:42:3b:3a:6b:00
        or substring(hardware, 1, 6) = 02:42:35:6c:75:00;
}

class "divB-short" {
  match if substring(hardware, 1, 6) = 02:42:b9:fd:f9:00
        or substring(hardware, 1, 6) = 02:42:4e:89:96:00;
  default-lease-time 1800;
  max-lease-time 1800;
}

class "divB-long" {
  match if substring(hardware, 1, 6) = 02:42:6f:c6:15:00;
  default-lease-time 43200;
  max-lease-time 43200;
}

# Kugisaki (VIP): alamat tetap berdasarkan MAC, di luar semua pool dinamis
host kugisaki {
  hardware ethernet 02:42:6b:21:47:00;
  fixed-address 192.234.3.99;
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

  pool {
    allow members of "divB-short";
    range 192.234.3.10 192.234.3.89;
  }

  pool {
    allow members of "divB-long";
    range 192.234.3.100 192.234.3.199;
  }
}
EOF

# Validasi
dhcpd -4 -t -cf /etc/dhcp/dhcpd.conf
if [ $? -ne 0 ]; then
    echo 'ERR: konfigurasi DHCP server tengen tidak valid'
    exit 1
fi

# Restart DHCP server
service isc-dhcp-server restart
sleep 1
service isc-dhcp-server status
