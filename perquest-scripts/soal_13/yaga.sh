#!/bin/sh
# Soal 13
#   - yaga: MariaDB DB-Master. Binary log aktif, database db_shibuya_K46 + tabel request_logs,
#     akses remote untuk seluruh Network 4 (192.234.4.0/24).
#   - Uji replikasi: sh /root/soal_13.sh uji   (insert baris baru di master)

# Mode uji: insert baris baru agar terlihat tersalin ke inumaki
if [ "$1" = uji ]; then
    mysql -e "INSERT INTO db_shibuya_K46.request_logs (client_ip, worker, method, path)
              VALUES ('10.0.0.1', 'yaga', 'TEST', '/uji-replikasi-$(date +%H%M%S)');"
    mysql -e "SELECT * FROM db_shibuya_K46.request_logs ORDER BY id DESC LIMIT 3;"
    exit
fi

# Install MariaDB jika belum ada
if ! command -v mariadbd >/dev/null; then
    apt-get update && apt-get install -y mariadb-server
fi

# Aktifkan binary log dan server-id 1
mkdir -p /var/log/mysql && chown mysql:mysql /var/log/mysql
cat > /etc/mysql/mariadb.conf.d/60-soal13.cnf <<'EOF'
[mysqld]
bind-address  = 0.0.0.0
server-id     = 1
log-bin       = /var/log/mysql/mysql-bin
binlog_format = ROW
EOF

service mariadb restart

# Buat database, tabel, user replikasi, dan user aplikasi
mysql <<'EOF'
CREATE DATABASE IF NOT EXISTS db_shibuya_K46;
CREATE TABLE IF NOT EXISTS db_shibuya_K46.request_logs (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    client_ip  VARCHAR(45)  NOT NULL,
    worker     VARCHAR(32),
    method     VARCHAR(8),
    path       VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User replikasi untuk inumaki
CREATE USER IF NOT EXISTS 'repl'@'192.234.4.%' IDENTIFIED BY 'repl46';
GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'repl'@'192.234.4.%';

-- Akses remote untuk seluruh node Network 4 (worker API, dll.)
CREATE USER IF NOT EXISTS 'shibuya'@'192.234.4.%' IDENTIFIED BY 'shibuya46';
GRANT ALL PRIVILEGES ON db_shibuya_K46.* TO 'shibuya'@'192.234.4.%';
FLUSH PRIVILEGES;
EOF

# Autostart
if [ ! -f /root/init.sh ]; then
    echo '#!/bin/sh' > /root/init.sh
fi
if ! grep -qF 'service mariadb start' /root/init.sh; then
    echo 'service mariadb start >> /root/soal_13.log 2>&1' >> /root/init.sh
fi
chmod 755 /root/init.sh

# Bukti
mysql -e "SHOW VARIABLES WHERE Variable_name IN ('server_id','log_bin','bind_address');"
mysql -e "SHOW MASTER STATUS;"
mysql -e "DESCRIBE db_shibuya_K46.request_logs;"
