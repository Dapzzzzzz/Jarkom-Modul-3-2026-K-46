#!/bin/sh
# Soal 12
#   - utahime: A record jujutsu.K46.com -> gojo 192.234.1.4, CNAME www, zona PTR untuk gojo,
#     dan DNS forwarder ke 192.168.122.1.
#   - Jalankan setelah soal 11.

ZONE=/etc/bind/jujutsu/jujutsu.K46.com
RZONE=/etc/bind/jujutsu/1.234.192.in-addr.arpa

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

# Zona master: forward dan reverse (PTR), transfer ke shoko
cat > /etc/bind/named.conf.local <<'EOF'
zone "jujutsu.K46.com" {
    type master;
    file "/etc/bind/jujutsu/jujutsu.K46.com";
    allow-transfer { 192.234.1.3; };
    also-notify { 192.234.1.3; };
    notify yes;
};

zone "1.234.192.in-addr.arpa" {
    type master;
    file "/etc/bind/jujutsu/1.234.192.in-addr.arpa";
    allow-transfer { 192.234.1.3; };
    also-notify { 192.234.1.3; };
    notify yes;
};
EOF

# Serial harus lebih besar dari serial soal 11 agar shoko ikut memperbarui
OLD=$(awk '/; serial/{print $1}' $ZONE 2>/dev/null)
SERIAL=$(date +%y%m%d%H%M)
if [ -n "$OLD" ] && [ "$SERIAL" -le "$OLD" ]; then
    SERIAL=$((OLD + 1))
fi

# Zona forward
mkdir -p /etc/bind/jujutsu
cat > $ZONE <<EOF
\$TTL 604800
@       IN  SOA ns1.jujutsu.K46.com. root.jujutsu.K46.com. (
            $SERIAL  ; serial
            604800      ; refresh
            86400       ; retry
            2419200     ; expire
            604800 )    ; negative cache TTL

@       IN  NS     ns1.jujutsu.K46.com.
@       IN  NS     ns2.jujutsu.K46.com.
@       IN  A      192.234.1.4
www     IN  CNAME  jujutsu.K46.com.
ns1     IN  A      192.234.1.2
ns2     IN  A      192.234.1.3
uji     IN  TXT    "serial $SERIAL"
EOF

# Zona reverse (PTR) untuk gojo
cat > $RZONE <<EOF
\$TTL 604800
@       IN  SOA ns1.jujutsu.K46.com. root.jujutsu.K46.com. (
            $SERIAL  ; serial
            604800      ; refresh
            86400       ; retry
            2419200     ; expire
            604800 )    ; negative cache TTL

@       IN  NS     ns1.jujutsu.K46.com.
@       IN  NS     ns2.jujutsu.K46.com.
4       IN  PTR    jujutsu.K46.com.
EOF

# Cek sintaks lalu restart named
named-checkconf
named-checkzone jujutsu.K46.com $ZONE
named-checkzone 1.234.192.in-addr.arpa $RZONE
service named restart

# Bukti
dig @127.0.0.1 jujutsu.K46.com A +short
dig @127.0.0.1 www.jujutsu.K46.com +short
dig @127.0.0.1 -x 192.234.1.4 +short
dig @127.0.0.1 google.com A +short | head -2
