#!/bin/sh
# Soal 6
#   - kugisaki: client DHCP biasa; harus selalu menerima 192.234.3.99 (static lease di tengen).

cat > /etc/network/interfaces <<'EOF'
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

# Renew lease
pkill udhcpc 2>/dev/null
ip addr flush dev eth0
ifdown eth0 2>/dev/null
ifup eth0

# Bukti: alamat harus 192.234.3.99
ip -4 -br addr show eth0
ip route | grep default
cat /etc/resolv.conf

# Cek apakah alamat sesuai reservasi
IP_ADDR=$(ip -4 addr show eth0 | grep -oP 'inet \K[\d.]+')
if [ "$IP_ADDR" = "192.234.3.99" ]; then
    echo 'OK: alamat IP sesuai bosku'
else
    echo 'ERR: alamat IP ga cocok bosku: $IP_ADDR'
fi
