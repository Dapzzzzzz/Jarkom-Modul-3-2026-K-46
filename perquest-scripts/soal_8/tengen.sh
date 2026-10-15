#!/bin/sh
# Soal 8 - tengen: packet capture DHCP (DISCOVER -> OFFER -> REQUEST -> ACK).
# Simpan di /root/soal_8.sh lalu jalankan: sh /root/soal_8.sh
# Capture aktif 40 detik. Selama itu, jalankan di miwa: sh /root/soal_8.sh
command -v tcpdump >/dev/null || { apt-get update && apt-get install -y tcpdump; }

rm -f /root/soal_8.log
timeout 40 tcpdump -i eth0 -n -vv -l 'udp and (port 67 or port 68)' > /root/soal_8.log 2>&1 &
echo "Capture berjalan, picu lease baru di client sekarang..."
wait

echo "== Urutan pesan =="
grep -E 'DHCP-Message' /root/soal_8.log
echo "== Detail (server, alamat diberikan, lease time, giaddr) =="
grep -E 'Server-ID|Your-IP|Lease-Time|Gateway-IP|Client-Ethernet' /root/soal_8.log
echo "Log lengkap: /root/soal_8.log"
