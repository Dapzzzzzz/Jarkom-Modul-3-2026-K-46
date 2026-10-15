#!/bin/sh
# Soal 1
#   - jichi: eth0 WAN (DHCP dari NAT), eth1-eth4 gateway Network 1-4,
#     IPv4 forwarding dan source NAT.

cat > /etc/network/interfaces <<'EOF'
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
    up sysctl -w net.ipv4.ip_forward=1
    up iptables -t nat -C POSTROUTING -s 192.234.0.0/16 -o eth0 -j MASQUERADE 2>/dev/null || iptables -t nat -A POSTROUTING -s 192.234.0.0/16 -o eth0 -j MASQUERADE

auto eth1
iface eth1 inet static
    address 192.234.1.1
    netmask 255.255.255.0

auto eth2
iface eth2 inet static
    address 192.234.2.1
    netmask 255.255.255.0

auto eth3
iface eth3 inet static
    address 192.234.3.1
    netmask 255.255.255.0

auto eth4
iface eth4 inet static
    address 192.234.4.1
    netmask 255.255.255.0
EOF

# Terapkan sekarang ke eth1-eth4
for N in 1 2 3 4; do
    ip addr flush dev eth$N
    ip addr add 192.234.$N.1/24 dev eth$N
    ip link set eth$N up
done

# IPv4 forwarding + source NAT lewat eth0 (WAN)
sysctl -w net.ipv4.ip_forward=1
if ! iptables -t nat -C POSTROUTING -s 192.234.0.0/16 -o eth0 -j MASQUERADE 2>/dev/null; then
    iptables -t nat -A POSTROUTING -s 192.234.0.0/16 -o eth0 -j MASQUERADE
fi

# Bukti
ip -4 -br addr
ip route
sysctl net.ipv4.ip_forward
iptables -t nat -S POSTROUTING
ping -c 3 192.168.122.1
