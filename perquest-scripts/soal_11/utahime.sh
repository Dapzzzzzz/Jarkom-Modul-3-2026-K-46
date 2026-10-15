#!/bin/sh
# Soal 11 - utahime: DNS Master (BIND9) untuk jujutsu.K46.com, transfer zona ke shoko 192.234.1.3.
# Simpan di /root/soal_11.sh lalu jalankan: sh /root/soal_11.sh
# Uji sinkronisasi: sh /root/soal_11.sh naikkan   (serial +1 dan record uji diubah)
ZONE=/etc/bind/jujutsu/jujutsu.K46.com

if [ "$1" = naikkan ]; then
    OLD=$(awk '/; serial/{print $1}' $ZONE)
    NEW=$((OLD + 1))
    sed -i "s/^\( *\)$OLD\( *; serial\)/\1$NEW\2/" $ZONE
    sed -i "s/^uji .*/uji     IN  TXT \"serial $NEW\"/" $ZONE
    named-checkzone jujutsu.K46.com $ZONE && rndc reload jujutsu.K46.com
    echo "Serial $OLD -> $NEW"
    exit
fi

command -v named >/dev/null || { apt-get update && apt-get install -y bind9 bind9utils; }

cat > /etc/bind/named.conf.local <<'EOF'
zone "jujutsu.K46.com" {
    type master;
    file "/etc/bind/jujutsu/jujutsu.K46.com";
    allow-transfer { 192.234.1.3; };
    also-notify { 192.234.1.3; };
    notify yes;
};
EOF

# Serial berbasis waktu (YYMMDDhhmm) agar selalu naik setiap script dijalankan ulang
SERIAL=$(date +%y%m%d%H%M)
mkdir -p /etc/bind/jujutsu
cat > $ZONE <<EOF
\$TTL 604800
@       IN  SOA ns1.jujutsu.K46.com. root.jujutsu.K46.com. (
            $SERIAL  ; serial
            604800      ; refresh
            86400       ; retry
            2419200     ; expire
            604800 )    ; negative cache TTL

@       IN  NS  ns1.jujutsu.K46.com.
@       IN  NS  ns2.jujutsu.K46.com.
ns1     IN  A   192.234.1.2
ns2     IN  A   192.234.1.3
uji     IN  TXT "serial $SERIAL"
EOF

named-checkconf
named-checkzone jujutsu.K46.com $ZONE
service named restart

# Autostart
[ -f /root/init.sh ] || echo '#!/bin/sh' > /root/init.sh
grep -qF 'service named start' /root/init.sh || echo 'service named start >> /root/soal_11.log 2>&1' >> /root/init.sh
chmod 755 /root/init.sh

# Bukti
service named status
dig @127.0.0.1 jujutsu.K46.com SOA +short
dig @127.0.0.1 jujutsu.K46.com NS +short
