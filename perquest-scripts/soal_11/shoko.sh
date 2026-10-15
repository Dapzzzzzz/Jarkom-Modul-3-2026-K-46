#!/bin/sh
# Soal 11
#   - shoko: DNS Slave (BIND9) untuk jujutsu.K46.com, menyalin zona dari utahime 192.234.1.2.
#   - Jalankan setelah utahime.

# Install BIND9 jika belum ada
if ! command -v named >/dev/null; then
    apt-get update && apt-get install -y bind9 bind9utils
fi

# Zona slave, ambil dari master utahime
cat > /etc/bind/named.conf.local <<'EOF'
zone "jujutsu.K46.com" {
    type slave;
    masters { 192.234.1.2; };
    file "/var/lib/bind/jujutsu.K46.com";
};
EOF

# Cek sintaks lalu restart named
named-checkconf
service named restart

# Bukti: zona tersalin dari master
sleep 3
service named status
ls -la /var/lib/bind/
dig @127.0.0.1 jujutsu.K46.com SOA +short
dig @127.0.0.1 uji.jujutsu.K46.com TXT +short
