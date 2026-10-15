#!/bin/sh
# Soal 5 - miwa (Divisi B long lease (3.100-3.199)): client DHCP biasa.
# Simpan di /root/soal_5.sh lalu jalankan: sh /root/soal_5.sh
cat > /etc/network/interfaces <<'EOF'
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

# Minta lease baru
pkill udhcpc 2>/dev/null
ip addr flush dev eth0
ifdown eth0 2>/dev/null
ifup eth0

# Bukti
ip -4 -br addr show eth0
ip route | grep default
cat /etc/resolv.conf
