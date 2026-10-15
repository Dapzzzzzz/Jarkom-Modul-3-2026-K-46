#!/bin/sh
# Soal 2: ISC DHCP Server tengen; Network 4 lokal tanpa pool; scope Network 2/3.
# ==== NODE TENGEN ====
set -eu
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export DEBIAN_FRONTEND=noninteractive
MODE=${1:-apply}
case "$MODE" in apply|--boot|--verify|--rebuild) ;; *) echo 'Mode tidak dikenal'; exit 1;; esac
[ "$(id -u)" = 0 ]
[ "$(hostname | tr '[:upper:]' '[:lower:]')" = tengen ] || { echo 'Jalankan pada tengen'; exit 1; }
ROOT=/root/no2-5
PARTS=$ROOT/perquest.d
CACHE=$ROOT/deb-cache
mkdir -p "$PARTS" "$CACHE/partial" /etc/dhcp /etc/default /var/lib/dhcp /run

verify() {
    dhcpd -4 -t -cf /etc/dhcp/dhcpd.conf || return 1
    service isc-dhcp-server status || return 1
    kill -0 "$(cat /run/dhcpd.pid)" || return 1
    ip -o -4 addr show dev eth0 | grep -Fq ' 192.229.4.10/24 ' || return 1
    printf 'SOAL_2: PASS\n'
}
if [ "$MODE" = --verify ]; then verify; exit; fi

if [ "$MODE" = apply ]; then
    if ! cmp -s "$0" /root/soal_2.sh; then cp "$0" /root/soal_2.sh; fi
    if [ ! -d "$ROOT/perquest-backup-before" ]; then
        mkdir -p "$ROOT/perquest-backup-before"
        [ ! -f /etc/dhcp/dhcpd.conf ] || cp -p /etc/dhcp/dhcpd.conf "$ROOT/perquest-backup-before/dhcpd.conf"
        [ ! -f /root/init.sh ] || cp -p /root/init.sh "$ROOT/perquest-backup-before/init.sh"
    fi
fi
if ! command -v dhcpd >/dev/null 2>&1; then
    CACHE_OK=0
    if ls "$CACHE"/*.deb >/dev/null 2>&1; then
        if dpkg -i "$CACHE"/*.deb; then CACHE_OK=1; fi
    fi
    if [ "$CACHE_OK" = 0 ] || ! command -v dhcpd >/dev/null 2>&1; then
        apt-get -o Acquire::ForceIPv4=true update
        apt-get -o Acquire::ForceIPv4=true -o Dir::Cache::archives="$CACHE" -o APT::Keep-Downloaded-Packages=true install -y --no-install-recommends isc-dhcp-server
    fi
fi

# Migrasi konfigurasi monolitik yang sudah ada: pertahankan class, pool, dan host.
# Fragment hanya dibuat bila belum ada. Menjalankan ulang soal 2 tidak mereset 4/5.
OLD=$ROOT/dhcpd.conf
[ -f "$OLD" ] || OLD=/etc/dhcp/dhcpd.conf
extract_blocks() {
    awk -v pattern="$1" '
        !printing && $0 ~ pattern { printing=1; depth=0 }
        printing {
            print
            line=$0; opens=gsub(/\{/,"&",line); closes=gsub(/\}/,"&",line)
            depth+=opens-closes
            if (depth==0) printing=0
        }
    ' "$OLD"
}
extract_pools() {
    awk -v network="$1" '
        !active && index($0,"subnet " network " netmask") == 1 {active=1; depth=1; next}
        active {
            line=$0; delta=gsub(/\{/,"&",line)-gsub(/\}/,"&",line)
            if (!printing && $0 ~ /^[[:space:]]*pool[[:space:]]*\{/) {printing=1; pdepth=0}
            if (printing) {print; pdepth+=delta; if (pdepth==0) printing=0}
            depth+=delta
            if (depth==0) exit
        }
    ' "$OLD"
}
for FILE in 10-soal4-classes.conf 20-soal5-classes.conf 30-extra-hosts.conf 40-network2-pools.conf 50-network3-pools.conf; do
    [ ! -e "$PARTS/$FILE" ] || continue
    if [ -f "$OLD" ]; then
        case "$FILE" in
            10-soal4-classes.conf) extract_blocks '^class "divA-' > "$PARTS/$FILE";;
            20-soal5-classes.conf)
                awk '/^option domain-name-servers |^option domain-name |^option domain-search /' "$OLD" > "$PARTS/$FILE"
                extract_blocks '^class "divB-' >> "$PARTS/$FILE";;
            30-extra-hosts.conf) extract_blocks '^host ' > "$PARTS/$FILE";;
            40-network2-pools.conf) extract_pools 192.229.2.0 > "$PARTS/$FILE";;
            50-network3-pools.conf) extract_pools 192.229.3.0 > "$PARTS/$FILE";;
        esac
    else
        : > "$PARTS/$FILE"
    fi
done

cat > "$ROOT/dhcpd.candidate.conf" <<'DHCP_BASE'
authoritative;
ddns-update-style none;
default-lease-time 3600;
max-lease-time 7200;
dhcp-cache-threshold 0;
lease-file-name "/root/no2-5/dhcpd.leases";
pid-file-name "/run/dhcpd.pid";
option subnet-mask 255.255.255.0;
include "/root/no2-5/perquest.d/10-soal4-classes.conf";
include "/root/no2-5/perquest.d/20-soal5-classes.conf";
include "/root/no2-5/perquest.d/30-extra-hosts.conf";

subnet 192.229.4.0 netmask 255.255.255.0 {
    option routers 192.229.4.1;
    option broadcast-address 192.229.4.255;
    # Subnet lokal tengen: tidak ada range/pool dinamis.
}
subnet 192.229.2.0 netmask 255.255.255.0 {
    option routers 192.229.2.1;
    option broadcast-address 192.229.2.255;
    include "/root/no2-5/perquest.d/40-network2-pools.conf";
}
subnet 192.229.3.0 netmask 255.255.255.0 {
    option routers 192.229.3.1;
    option broadcast-address 192.229.3.255;
    include "/root/no2-5/perquest.d/50-network3-pools.conf";
}
DHCP_BASE

# ==== VALIDASI SEBELUM MENGGANTI KONFIGURASI AKTIF ====
dhcpd -4 -t -cf "$ROOT/dhcpd.candidate.conf"
HAD_ACTIVE=0
HAD_PERSISTENT=0
HAD_DEFAULTS=0
WAS_RUNNING=0
if [ -f /etc/dhcp/dhcpd.conf ]; then
    cp /etc/dhcp/dhcpd.conf "$ROOT/dhcpd.previous.conf"
    HAD_ACTIVE=1
fi
if [ -f "$ROOT/dhcpd.conf" ]; then
    cp "$ROOT/dhcpd.conf" "$ROOT/dhcpd.previous-persistent.conf"
    HAD_PERSISTENT=1
fi
if [ -f /etc/default/isc-dhcp-server ]; then
    cp /etc/default/isc-dhcp-server "$ROOT/previous-defaults"
    HAD_DEFAULTS=1
fi
if [ -s /run/dhcpd.pid ] && kill -0 "$(cat /run/dhcpd.pid)" 2>/dev/null; then WAS_RUNNING=1; fi
restore_previous() {
    if [ "$HAD_ACTIVE" = 1 ]; then cp "$ROOT/dhcpd.previous.conf" /etc/dhcp/dhcpd.conf; else rm -f /etc/dhcp/dhcpd.conf; fi
    if [ "$HAD_PERSISTENT" = 1 ]; then cp "$ROOT/dhcpd.previous-persistent.conf" "$ROOT/dhcpd.conf"; else rm -f "$ROOT/dhcpd.conf"; fi
    if [ "$HAD_DEFAULTS" = 1 ]; then cp "$ROOT/previous-defaults" /etc/default/isc-dhcp-server; else rm -f /etc/default/isc-dhcp-server; fi
    if [ "$WAS_RUNNING" = 1 ]; then service isc-dhcp-server restart || true; else service isc-dhcp-server stop || true; fi
}
cp "$ROOT/dhcpd.candidate.conf" "$ROOT/dhcpd.conf"
cp "$ROOT/dhcpd.conf" /etc/dhcp/dhcpd.conf
cat > /etc/default/isc-dhcp-server <<'DHCP_DEFAULTS'
INTERFACESv4="eth0"
INTERFACESv6=""
DHCPDv4_CONF="/etc/dhcp/dhcpd.conf"
DHCPDv4_PID="/run/dhcpd.pid"
DHCP_DEFAULTS
if [ ! -f "$ROOT/dhcpd.leases" ]; then
    if [ -f /var/lib/dhcp/dhcpd.leases ]; then
        cp /var/lib/dhcp/dhcpd.leases "$ROOT/dhcpd.leases"
    else
        : > "$ROOT/dhcpd.leases"
    fi
fi
ln -sfn "$ROOT/dhcpd.leases" /var/lib/dhcp/dhcpd.leases

install_startup() {
    [ -f /root/init.sh ] || printf '#!/bin/sh\n' > /root/init.sh
    # Ganti hook server lama saja; hook nomor 1 dan relay tidak diubah.
    awk '
        /^# BEGIN JARKOM-NO2-5-SERVER$/ || /^# BEGIN JARKOM-MODUL3-SOAL2$/ {skip=1; next}
        /^# END JARKOM-NO2-5-SERVER$/ || /^# END JARKOM-MODUL3-SOAL2$/ {skip=0; next}
        !skip {print}
    ' /root/init.sh > "$ROOT/init.next"
    cat >> "$ROOT/init.next" <<'STARTUP'

# BEGIN JARKOM-MODUL3-SOAL2
sh /root/soal_2.sh --boot >> /root/no2-5-boot.log 2>&1
# END JARKOM-MODUL3-SOAL2
STARTUP
    sh -n "$ROOT/init.next"
    cat "$ROOT/init.next" > /root/init.sh
    chmod 755 /root/init.sh /root/soal_2.sh
}
if [ "$MODE" = --boot ]; then
    service isc-dhcp-server start
    verify
else
    if ! service isc-dhcp-server restart || ! verify; then
        restore_previous
        echo 'Service/validasi gagal; sumber persisten dan konfigurasi sebelumnya dipulihkan' >&2
        exit 1
    fi
    if [ "$MODE" = apply ]; then install_startup; fi
fi
