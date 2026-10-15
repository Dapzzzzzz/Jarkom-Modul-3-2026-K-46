#!/bin/sh
# Soal 3: relay eth2/eth3 -> tengen melalui eth4.
# ==== NODE JICHI ====
set -eu
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export DEBIAN_FRONTEND=noninteractive
MODE=${1:-apply}
case "$MODE" in apply|--boot|--verify) ;; *) echo 'Invalid mode' >&2; exit 1;; esac
[ "$(hostname | tr '[:upper:]' '[:lower:]')" = jichi ] || { echo 'Jalankan pada jichi'; exit 1; }
[ "$(id -u)" = 0 ] || { echo 'Run as root' >&2; exit 1; }
ROOT=/root/no2-5
CACHE=$ROOT/deb-cache
mkdir -p "$ROOT" "$CACHE/partial"
install_package() {
    BIN=$1
    PKG=$2
    if command -v "$BIN" >/dev/null 2>&1; then return; fi
    CACHE_OK=0
    if ls "$CACHE"/*.deb >/dev/null 2>&1; then
        if dpkg -i "$CACHE"/*.deb; then CACHE_OK=1; fi
    fi
    if [ "$CACHE_OK" = 0 ] || ! command -v "$BIN" >/dev/null 2>&1; then
        apt-get -o Acquire::ForceIPv4=true -o Acquire::Retries=2 -o Acquire::http::Timeout=15 update
        apt-get -o Acquire::ForceIPv4=true -o Dir::Cache::archives="$CACHE" -o APT::Keep-Downloaded-Packages=true install -y --no-install-recommends "$PKG"
    fi
    command -v "$BIN" >/dev/null 2>&1
}
backup_first() {
    BACKUP=$ROOT/backup-before
    if [ ! -d "$BACKUP" ]; then
        mkdir -p "$BACKUP"
        [ ! -f /root/init.sh ] || cp -p /root/init.sh "$BACKUP/init.sh"
        [ ! -f /etc/dhcp/dhcpd.conf ] || cp -p /etc/dhcp/dhcpd.conf "$BACKUP/dhcpd.conf"
        [ ! -f /etc/default/isc-dhcp-server ] || cp -p /etc/default/isc-dhcp-server "$BACKUP/isc-dhcp-server"
        [ ! -f /etc/default/isc-dhcp-relay ] || cp -p /etc/default/isc-dhcp-relay "$BACKUP/isc-dhcp-relay"
    fi
}
boot_hook() {
    SCRIPT=$1
    LABEL=$2
    if [ ! -f /root/init.sh ]; then printf '#!/bin/sh\n' > /root/init.sh; fi
    if ! grep -q "^# BEGIN $LABEL\$" /root/init.sh; then
        printf '\n# BEGIN %s\nsh /root/%s --boot >> /root/no2-5-boot.log 2>&1\n# END %s\n' "$LABEL" "$SCRIPT" "$LABEL" >> /root/init.sh
    fi
    chmod 755 /root/init.sh "/root/$SCRIPT"
    sh -n /root/init.sh
}

verify() {
    service isc-dhcp-relay status
    PID=$(cat /run/dhcrelay.pid)
    kill -0 "$PID"
    ps -p "$PID" -o args= | grep -F -- '-id eth2 -id eth3 -iu eth4'
    if [ "$MODE" != --boot ]; then ping -c 2 -i 0.2 -W 3 192.229.4.10; fi
    printf 'RESULT: jichi DHCP_RELAY PASS\n'
}
if [ "$MODE" = --verify ]; then verify; exit; fi
if [ "$MODE" = apply ]; then
    if ! cmp -s "$0" /root/no3-jichi.sh; then cp "$0" /root/no3-jichi.sh; fi
    backup_first
fi
install_package dhcrelay isc-dhcp-relay
mkdir -p /etc/default /run
cat > /etc/default/isc-dhcp-relay <<'RELAY_DEFAULTS'
SERVERS="192.229.4.10"
INTERFACES=""
OPTIONS="-4 -id eth2 -id eth3 -iu eth4"
RELAY_DEFAULTS
if [ "$MODE" = apply ]; then boot_hook no3-jichi.sh JARKOM-NO2-5-RELAY; fi
if [ "$MODE" = --boot ]; then service isc-dhcp-relay start; else service isc-dhcp-relay restart; fi
sleep 1
verify
