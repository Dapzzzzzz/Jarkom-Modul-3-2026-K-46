#!/bin/sh
# Soal 5
#   - fushiguro (Divisi A pool 1 (2.10-2.35)): client DHCP biasa.

# eth0 memakai DHCP
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
