#!/bin/sh
# Soal 9 - itadori (Network 2): paksa minta lease baru. Gagal saat relay mati, berhasil setelah dipulihkan.
# Simpan di /root/soal_9.sh lalu jalankan: sh /root/soal_9.sh
pkill udhcpc 2>/dev/null
ip addr flush dev eth0
echo "== Mencoba mendapatkan lease =="
if udhcpc -i eth0 -n -q -t 3 -T 2; then
    echo "PASS: lease diperoleh"
    ifdown eth0 2>/dev/null; ifup eth0    # kembalikan daemon DHCP client
else
    echo "FAIL: tidak ada jawaban DHCP (relay terputus?)"
fi
ip -4 -br addr show eth0
ip route | grep default
