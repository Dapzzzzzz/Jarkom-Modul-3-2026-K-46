#!/bin/sh
# Soal 13
#   - inumaki: MariaDB DB-Slave yang menyalin data dari yaga (192.234.4.8) secara realtime.
#   - Jalankan setelah yaga. Cek hasil replikasi: sh /root/soal_13.sh cek

MASTER=192.234.4.8

if [ "$1" != cek ]; then
    # Install MariaDB jika belum ada
    if ! command -v mariadbd >/dev/null; then
        apt-get update && apt-get install -y mariadb-server
    fi

    # Server-id 2, relay log, dan read-only
    mkdir -p /var/log/mysql && chown mysql:mysql /var/log/mysql
    cat > /etc/mysql/mariadb.conf.d/60-soal13.cnf <<'EOF'
[mysqld]
bind-address = 0.0.0.0
server-id    = 2
relay-log    = /var/log/mysql/relay-bin
read_only    = 1
EOF
    service mariadb restart

    # Mulai dari binlog pertama master agar database dan tabel yang sudah ada ikut tersalin
    FILE=$(mysql -h $MASTER -u repl -prepl46 -N -e "SHOW BINARY LOGS" | head -1 | awk '{print $1}')
    echo "Binlog awal master: $FILE"
    mysql <<EOF
STOP SLAVE;
RESET SLAVE ALL;
DROP DATABASE IF EXISTS db_shibuya_K46;
CHANGE MASTER TO
    MASTER_HOST='$MASTER',
    MASTER_USER='repl',
    MASTER_PASSWORD='repl46',
    MASTER_LOG_FILE='$FILE',
    MASTER_LOG_POS=4;
START SLAVE;
EOF

    # Autostart
    if [ ! -f /root/init.sh ]; then
        echo '#!/bin/sh' > /root/init.sh
    fi
    if ! grep -qF 'service mariadb start' /root/init.sh; then
        echo 'service mariadb start >> /root/soal_13.log 2>&1' >> /root/init.sh
    fi
    chmod 755 /root/init.sh

    # Tunggu IO thread terhubung ke master (maks. 60 detik)
    for i in $(seq 1 30); do
        if mysql -e "SHOW SLAVE STATUS\G" | grep -q 'Slave_IO_Running: Yes'; then
            break
        fi
        sleep 2
    done
fi

# Bukti
mysql -e "SHOW SLAVE STATUS\G" | grep -E 'Master_Host|Master_Log_File|Slave_IO_Running|Slave_SQL_Running|Seconds_Behind|Last_.*Error:'
mysql -e "SELECT * FROM db_shibuya_K46.request_logs ORDER BY id DESC LIMIT 3;"
