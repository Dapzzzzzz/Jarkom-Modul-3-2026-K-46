#!/bin/sh
# Soal 3
#   - jichi: DHCP relay. eth2 (Network 2) dan eth3 (Network 3) sisi client,
#     eth4 sisi Data Center, menuju tengen 192.234.4.10.

# Install isc-dhcp-relay jika belum ada
if ! command -v dhcrelay >/dev/null; then
    apt-get update && apt-get install -y isc-dhcp-relay
fi

# Relay: terima dari eth2/eth3 (client), teruskan lewat eth4 ke tengen
cat > /etc/default/isc-dhcp-relay <<'EOF'
SERVERS="192.234.4.10"
INTERFACES=""
OPTIONS="-4 -id eth2 -id eth3 -iu eth4"
EOF

# Restart relay
service isc-dhcp-relay restart
sleep 1
service isc-dhcp-relay status
ps -eo args | grep '[d]hcrelay'
ping -c 2 192.234.4.10
