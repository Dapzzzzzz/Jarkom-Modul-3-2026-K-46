#!/bin/sh
# Soal 11 - shoko: DNS Slave (BIND9) untuk jujutsu.K46.com, menyalin zona dari utahime 192.234.1.2.
# Simpan di /root/soal_11.sh lalu jalankan: sh /root/soal_11.sh   (jalankan setelah utahime)
command -v named >/dev/null || { apt-get update && apt-get install -y bind9 bind9utils; }

cat > /etc/bind/named.conf.local <<'EOF'
zone "jujutsu.K46.com" {
    type slave;
    masters { 192.234.1.2; };
    file "/var/lib/bind/jujutsu.K46.com";
};
EOF

named-checkconf
service named restart

# Autostart
[ -f /root/init.sh ] || echo '#!/bin/sh' > /root/init.sh
grep -qF 'service named start' /root/init.sh || echo 'service named start >> /root/soal_11.log 2>&1' >> /root/init.sh
chmod 755 /root/init.sh

# Bukti: zona tersalin dari master
sleep 3
service named status
ls -la /var/lib/bind/
dig @127.0.0.1 jujutsu.K46.com SOA +short
dig @127.0.0.1 uji.jujutsu.K46.com TXT +short
