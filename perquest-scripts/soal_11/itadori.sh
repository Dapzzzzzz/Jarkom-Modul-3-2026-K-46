#!/bin/sh
# Soal 11 - itadori (client): query ke DNS Master dan DNS Slave, serial harus sama.
# Simpan di /root/soal_11.sh lalu jalankan: sh /root/soal_11.sh
for NS in 192.234.1.2 192.234.1.3; do
    echo "== dig @$NS =="
    dig @$NS jujutsu.K46.com SOA +noall +answer
    dig @$NS jujutsu.K46.com NS +noall +answer
    dig @$NS uji.jujutsu.K46.com TXT +noall +answer
done

S1=$(dig @192.234.1.2 jujutsu.K46.com SOA +short | awk '{print $3}')
S2=$(dig @192.234.1.3 jujutsu.K46.com SOA +short | awk '{print $3}')
[ -n "$S1" ] && [ "$S1" = "$S2" ] && echo "PASS: serial master = slave ($S1)" || echo "FAIL: serial master=$S1 slave=$S2"
