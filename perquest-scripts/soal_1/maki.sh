#!/bin/sh
# Soal 1
#   - maki: IP statis 192.234.4.3/24, gateway 192.234.4.1.

# Konfigurasi permanen (dibaca ulang saat boot)
cat > /etc/network/interfaces <<'EOF'
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address 192.234.4.3
    netmask 255.255.255.0
    gateway 192.234.4.1
    up echo "nameserver 192.168.122.1" > /etc/resolv.conf
EOF

# Terapkan sekarang
ip addr flush dev eth0
ip addr add 192.234.4.3/24 dev eth0
ip link set eth0 up
ip route replace default via 192.234.4.1
echo "nameserver 192.168.122.1" > /etc/resolv.conf   # nameserver awal agar bisa mengunduh paket

# Bukti
ip -4 -br addr show eth0
ip route | grep default
ping -c 3 192.234.4.1
# Akses eksternal: ping -c 3 google.com
