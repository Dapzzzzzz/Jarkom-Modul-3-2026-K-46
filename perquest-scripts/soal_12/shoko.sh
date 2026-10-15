#!/bin/sh
# Soal 12
#   - shoko: slave juga untuk zona PTR, dan forwarder yang sama dengan master
#     (client memakai 192.234.1.3 sebagai DNS kedua).
#   - Jalankan setelah utahime.

# Forwarder + izinkan recursion untuk seluruh jaringan internal
cat > /etc/bind/named.conf.options <<'EOF'
options {
    directory "/var/cache/bind";
    forwarders { 192.168.122.1; };
    allow-query { any; };
    allow-recursion { 127.0.0.1; 192.234.0.0/16; };
    dnssec-validation no;
    listen-on { any; };
    listen-on-v6 { none; };
};
EOF

# Zona slave: forward dan reverse (PTR)
cat > /etc/bind/named.conf.local <<'EOF'
zone "jujutsu.K46.com" {
    type slave;
    masters { 192.234.1.2; };
    file "/var/lib/bind/jujutsu.K46.com";
};

zone "1.234.192.in-addr.arpa" {
    type slave;
    masters { 192.234.1.2; };
    file "/var/lib/bind/1.234.192.in-addr.arpa";
};
EOF

# Cek sintaks lalu restart named
named-checkconf
service named restart

# Bukti
sleep 3
ls -la /var/lib/bind/
dig @127.0.0.1 www.jujutsu.K46.com +short
dig @127.0.0.1 -x 192.234.1.4 +short
dig @127.0.0.1 google.com A +short | head -2
