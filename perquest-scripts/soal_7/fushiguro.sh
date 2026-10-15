#!/bin/sh
# Soal 7 - fushiguro (Divisi A pool 1): periksa konfigurasi jaringan hasil DHCP.
# Simpan di /root/soal_7.sh lalu jalankan: sh /root/soal_7.sh
NET=2; LOW=10; HIGH=35
ok()  { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; }

ip -4 -br addr show eth0
ip route
cat /etc/resolv.conf

CIDR=$(ip -4 -o addr show dev eth0 | awk '{print $4}')
IP=${CIDR%/*}; MASK=${CIDR#*/}; LAST=${IP##*.}
BRD=$(ip -4 -o addr show dev eth0 | awk '{for(i=1;i<=NF;i++) if($i=="brd") print $(i+1)}')
GW=$(ip route | awk '/^default/{print $3}')

[ "${IP%.*}" = "192.234.$NET" ] && [ "$LAST" -ge "$LOW" ] && [ "$LAST" -le "$HIGH" ] && ok "IP $IP dalam rentang .$NET.$LOW-.$NET.$HIGH" || bad "IP $IP di luar kebijakan"
[ "$MASK" = 24 ] && ok "subnet mask /24 (255.255.255.0)" || bad "mask /$MASK"
[ "$BRD" = "192.234.$NET.255" ] && ok "broadcast $BRD" || bad "broadcast $BRD"
[ "$GW" = "192.234.$NET.1" ] && ok "gateway $GW" || bad "gateway $GW"
grep -q '^nameserver 192.234.1.2$' /etc/resolv.conf && grep -q '^nameserver 192.234.1.3$' /etc/resolv.conf && ok "DNS 192.234.1.2 dan 192.234.1.3" || bad "DNS"
grep -q '^search K46.com$' /etc/resolv.conf && ok "domain-search K46.com" || bad "domain-search"
ping -c 2 -W 2 "$GW" >/dev/null && ok "ping gateway" || bad "ping gateway"
ping -c 2 -W 3 192.234.4.10 >/dev/null && ok "ping tengen" || bad "ping tengen"
