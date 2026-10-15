#!/bin/sh
# Soal 1 - shoko: IP statis 192.234.1.3/24, gateway 192.234.1.1.
# Simpan di /root/soal_1.sh lalu jalankan: sh /root/soal_1.sh
IP=192.234.1.3
GW=192.234.1.1
DNS=192.168.122.1   # nameserver awal agar bisa mengunduh paket

# Konfigurasi permanen (dibaca ulang saat boot)
cat > /etc/network/interfaces <<'EOF'
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address 192.234.1.3
    netmask 255.255.255.0
    gateway 192.234.1.1
    up echo "nameserver 192.168.122.1" > /etc/resolv.conf
EOF

# Terapkan sekarang
ip addr flush dev eth0
ip addr add $IP/24 dev eth0
ip link set eth0 up
ip route replace default via $GW
echo "nameserver $DNS" > /etc/resolv.conf

# Bukti
ip -4 -br addr show eth0
ip route | grep default
ping -c 3 $GW
# Akses eksternal: ping -c 3 google.com
