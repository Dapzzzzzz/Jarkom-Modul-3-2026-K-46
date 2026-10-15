#!/bin/sh
# Soal 9
#   - itadori (Network 2): paksa minta lease baru. Gagal saat relay mati, berhasil setelah dipulihkan.

# Lepas lease lama dan hentikan DHCP client yang sedang berjalan
pkill udhcpc 2>/dev/null
ip addr flush dev eth0

# Coba minta lease sekali (3 percobaan, jeda 2 detik)
echo "== Mencoba mendapatkan lease =="
if udhcpc -i eth0 -n -q -t 3 -T 2; then
    echo "OK: lease diperoleh"
    # Kembalikan daemon DHCP client
    ifdown eth0 2>/dev/null
    ifup eth0
else
    echo "ERR: tidak ada jawaban DHCP (relay terputus?)"
fi

ip -4 -br addr show eth0
ip route | grep default
