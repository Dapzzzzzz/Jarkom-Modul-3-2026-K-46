#!/bin/sh
# Soal 12 - itadori (client): uji A, CNAME www, PTR gojo, dan akses domain internet.
# Simpan di /root/soal_12.sh lalu jalankan: sh /root/soal_12.sh
echo "== A record =="
dig jujutsu.K46.com A +noall +answer
echo "== CNAME www =="
dig www.jujutsu.K46.com +noall +answer
echo "== PTR 192.234.1.4 =="
dig -x 192.234.1.4 +noall +answer
echo "== Lewat DNS Slave =="
dig @192.234.1.3 www.jujutsu.K46.com +short
dig @192.234.1.3 -x 192.234.1.4 +short
echo "== Domain internet =="
ping -c 3 google.com
