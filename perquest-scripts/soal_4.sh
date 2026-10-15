#!/bin/sh
# Soal 4: dua pool Network 2 berdasarkan MAC; .36-.69 tidak dialokasikan.
# ==== NODE TENGEN ====
set -eu
[ "$(id -u)" = 0 ]
[ "$(hostname | tr '[:upper:]' '[:lower:]')" = tengen ] || { echo 'Jalankan pada tengen'; exit 1; }
PARTS=/root/no2-5/perquest.d
[ -f /root/soal_2.sh ] || { echo 'Jalankan soal_2.sh terlebih dahulu'; exit 1; }
[ -d "$PARTS" ]
BACKUP=/root/no2-5/soal4-last-good
mkdir -p "$BACKUP"
cp "$PARTS/10-soal4-classes.conf" "$BACKUP/classes.conf"
cp "$PARTS/40-network2-pools.conf" "$BACKUP/pools.conf"

# ==== KONFIGURASI CLASS MAC ====
cat > "$PARTS/10-soal4-classes.conf" <<'CLASSES'
class "divA-pool1" {
  match if substring(hardware, 1, 6) = 02:42:b1:2c:43:00
        or substring(hardware, 1, 6) = 02:42:40:6b:23:00;
}

class "divA-pool2" {
  match if substring(hardware, 1, 6) = 02:42:3b:3a:6b:00
        or substring(hardware, 1, 6) = 02:42:35:6c:75:00;
}
CLASSES

# ==== KONFIGURASI POOL ====
cat > "$PARTS/40-network2-pools.conf" <<'POOLS'
  pool {
    allow members of "divA-pool1";
    range 192.229.2.10 192.229.2.35;
  }

  pool {
    allow members of "divA-pool2";
    range 192.229.2.70 192.229.2.95;
  }
POOLS

# ==== VALIDASI + RESTART SERVER ====
if ! sh /root/soal_2.sh --rebuild; then
    cp "$BACKUP/classes.conf" "$PARTS/10-soal4-classes.conf"
    cp "$BACKUP/pools.conf" "$PARTS/40-network2-pools.conf"
    sh /root/soal_2.sh --rebuild || true
    echo 'Konfigurasi tidak diterapkan; fragment sebelumnya dipulihkan' >&2
    exit 1
fi
printf 'SOAL_4: PASS\n'

# ==== VERIFIKASI CLIENT (setelah soal 5 menyiapkan DHCP client) ====
# Pada Itadori/Fushiguro: sh /root/no2-client.sh <nama> --renew
# IP harus 192.229.2.10-35.
# Pada Zenin/Okkotsu: sh /root/no2-client.sh <nama> --renew
# IP harus 192.229.2.70-95.
