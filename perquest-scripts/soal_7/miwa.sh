#!/bin/sh
# Soal 7
#   - miwa (Divisi B long lease): periksa konfigurasi jaringan hasil DHCP.

NET=3; LOW=100; HIGH=199

ip -4 -br addr show eth0
ip route
cat /etc/resolv.conf

# Ambil CIDR (IP/Mask) dari eth0, lalu pisahkan menjadi IP, MASK, dan LAST octet
CIDR=$(ip -4 -o addr show dev eth0 | awk '{print $4}')
IP=${CIDR%/*}; MASK=${CIDR#*/}; LAST=${IP##*.}

# Ambil broadcast dan gateway
BRD=$(ip -4 -o addr show dev eth0 | awk '{for(i=1;i<=NF;i++) if($i=="brd") print $(i+1)}')
GW=$(ip route | awk '/^default/{print $3}')

# Cek apakah IP berada dalam rentang yang diizinkan
if [ "${IP%.*}" = "192.234.$NET" ] && [ "$LAST" -ge "$LOW" ] && [ "$LAST" -le "$HIGH" ]; then
    echo "OK: IP $IP dalam rentang .$NET.$LOW-.$NET.$HIGH"
else
    echo "ERR: IP $IP di luar kebijakan"
fi

# Cek subnet mask
if [ "$MASK" = 24 ]; then
    echo "OK: subnet mask /24"
else
    echo "ERR: subnet mask /$MASK, seharusnya /24"
fi

# Cek broadcast
if [ "$BRD" = "192.234.$NET.255" ]; then
    echo "OK: broadcast $BRD"
else
    echo "ERR: broadcast $BRD, seharusnya 192.234.$NET.255"
fi

# Cek gateway
if [ "$GW" = "192.234.$NET.1" ]; then
    echo "OK: gateway $GW"
else
    echo "ERR: gateway $GW, seharusnya 192.234.$NET.1"
fi

# Cek DNS
if grep -q '^nameserver 192.234.1.2$' /etc/resolv.conf && grep -q '^nameserver 192.234.1.3$' /etc/resolv.conf; then
    echo "OK: DNS 192.234.1.2 dan 192.234.1.3"
else
    echo "ERR: DNS tidak ditemukan"
fi

# Cek domain search
if grep -q '^search K46.com$' /etc/resolv.conf; then
    echo "OK: domain-search K46.com"
else
    echo "ERR: domain-search K46.com tidak ditemukan"
fi

# Cek ping ke gateway
if ping -c 2 -W 3 "$GW" >/dev/null; then
    echo "OK: ping gateway $GW"
else
    echo "ERR: ping gateway $GW gagal"
fi

if ping -c 2 -W 3 192.234.4.10 >/dev/null; then
    echo "OK: ping tengen"
else
    echo "ERR: ping tengen gagal"
fi
