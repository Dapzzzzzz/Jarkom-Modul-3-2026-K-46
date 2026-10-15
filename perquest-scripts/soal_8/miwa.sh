#!/bin/sh
# Soal 8
#   - miwa (Network 3): minta lease baru saat tcpdump berjalan di tengen.

# Lepas lease lama dan hentikan DHCP client yang sedang berjalan
pkill udhcpc 2>/dev/null
ip addr flush dev eth0

# Nyalakan ulang eth0 agar client mengirim DHCPDISCOVER baru
ifdown eth0 2>/dev/null
ifup eth0

ip -4 -br addr show eth0
