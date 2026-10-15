#!/bin/sh
# Soal 8 - miwa (Network 3): minta lease baru saat tcpdump berjalan di tengen.
# Simpan di /root/soal_8.sh lalu jalankan: sh /root/soal_8.sh
pkill udhcpc 2>/dev/null
ip addr flush dev eth0
ifdown eth0 2>/dev/null
ifup eth0
ip -4 -br addr show eth0
