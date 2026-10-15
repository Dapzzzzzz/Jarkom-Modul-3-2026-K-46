#!/bin/sh
# Soal 11
#   - itadori (client): query ke DNS Master dan DNS Slave, serial harus sama.

# Query SOA, NS, dan record uji ke master (1.2) dan slave (1.3)
for NS in 192.234.1.2 192.234.1.3; do
    echo "== dig @$NS =="
    dig @$NS jujutsu.K46.com SOA +noall +answer
    dig @$NS jujutsu.K46.com NS +noall +answer
    dig @$NS uji.jujutsu.K46.com TXT +noall +answer
done

# Ambil serial dari master dan slave
S1=$(dig @192.234.1.2 jujutsu.K46.com SOA +short | awk '{print $3}')
S2=$(dig @192.234.1.3 jujutsu.K46.com SOA +short | awk '{print $3}')

# Cek apakah serial master dan slave sama
if [ -n "$S1" ] && [ "$S1" = "$S2" ]; then
    echo "OK: serial master = slave ($S1)"
else
    echo "ERR: serial master=$S1 slave=$S2"
fi
