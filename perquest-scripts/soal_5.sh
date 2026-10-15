#!/bin/sh
# Soal 5: kebijakan server + DHCP client dengan penerimaan DNS/domain-search.
# Node tengen: jalankan tanpa argumen. Client: nama terdeteksi dari hostname.
set -eu
NODE=$(printf '%s' "${1:-$(hostname)}" | tr '[:upper:]' '[:lower:]')
case "$NODE" in
    tengen)
        # ==== NODE TENGEN ====
        cat > /root/soal_5-tengen.sh <<'SERVER_SCRIPT'
#!/bin/sh
# Soal 5: short lease 1800s, long lease 43200s, DNS dan domain-search.
# ==== NODE TENGEN ====
set -eu
[ "$(id -u)" = 0 ]
[ "$(hostname | tr '[:upper:]' '[:lower:]')" = tengen ] || { echo 'Jalankan pada tengen'; exit 1; }
PARTS=/root/no2-5/perquest.d
[ -f /root/soal_2.sh ] || { echo 'Jalankan soal_2.sh terlebih dahulu'; exit 1; }
[ -d "$PARTS" ]
BACKUP=/root/no2-5/soal5-last-good
mkdir -p "$BACKUP"
cp "$PARTS/20-soal5-classes.conf" "$BACKUP/classes.conf"
cp "$PARTS/50-network3-pools.conf" "$BACKUP/pools.conf"

# ==== KONFIGURASI CLASS MAC ====
cat > "$PARTS/20-soal5-classes.conf" <<'CLASSES'
option domain-name-servers 192.229.1.2, 192.229.1.3;
option domain-name "K46.com";
option domain-search "K46.com";

class "divB-short" {
  match if substring(hardware, 1, 6) = 02:42:b9:fd:f9:00
        or substring(hardware, 1, 6) = 02:42:4e:89:96:00;
  min-lease-time 1800;
  default-lease-time 1800;
  max-lease-time 1800;
}

class "divB-long" {
  match if substring(hardware, 1, 6) = 02:42:6f:c6:15:00;
  min-lease-time 43200;
  default-lease-time 43200;
  max-lease-time 43200;
}
CLASSES

# ==== KONFIGURASI POOL ====
cat > "$PARTS/50-network3-pools.conf" <<'POOLS'
  pool {
    allow members of "divB-short";
    min-lease-time 1800;
    default-lease-time 1800;
    max-lease-time 1800;
    range 192.229.3.10 192.229.3.89;
  }

  pool {
    allow members of "divB-long";
    min-lease-time 43200;
    default-lease-time 43200;
    max-lease-time 43200;
    range 192.229.3.100 192.229.3.199;
  }
POOLS

# ==== VALIDASI + RESTART SERVER ====
if ! sh /root/soal_2.sh --rebuild; then
    cp "$BACKUP/classes.conf" "$PARTS/20-soal5-classes.conf"
    cp "$BACKUP/pools.conf" "$PARTS/50-network3-pools.conf"
    sh /root/soal_2.sh --rebuild || true
    echo 'Konfigurasi tidak diterapkan; fragment sebelumnya dipulihkan' >&2
    exit 1
fi
printf 'SOAL_5: PASS\n'
SERVER_SCRIPT
        sh /root/soal_5-tengen.sh
        ;;
    itadori|fushiguro|zenin|okkotsu|ino|kusakabe|miwa)
        # ==== NODE CLIENT DIVISI A DAN B ====
        cat > /root/no2-client.sh <<'CLIENT_SCRIPT'
#!/bin/sh
# DHCP client setup for K-46, questions 2-5.
set -eu
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
NODE=$(printf '%s' "${1:-$(hostname)}" | tr '[:upper:]' '[:lower:]')
MODE=${2:-apply}
ROOT=/root/no2-5
PIDFILE=/run/no2-5-udhcpc.pid
[ "$(id -u)" = 0 ] || { echo 'Run as root'; exit 1; }
case "$MODE" in apply|--boot|--verify|--renew) ;; *) echo 'Invalid mode'; exit 1;; esac
case "$NODE" in
    itadori) MAC=02:42:b1:2c:43:00; NET=2; LOW=10; HIGH=35; EXPECTED_LEASE=3600;;
    fushiguro) MAC=02:42:40:6b:23:00; NET=2; LOW=10; HIGH=35; EXPECTED_LEASE=3600;;
    zenin) MAC=02:42:3b:3a:6b:00; NET=2; LOW=70; HIGH=95; EXPECTED_LEASE=3600;;
    okkotsu) MAC=02:42:35:6c:75:00; NET=2; LOW=70; HIGH=95; EXPECTED_LEASE=3600;;
    ino) MAC=02:42:b9:fd:f9:00; NET=3; LOW=10; HIGH=89; EXPECTED_LEASE=1800;;
    kusakabe) MAC=02:42:4e:89:96:00; NET=3; LOW=10; HIGH=89; EXPECTED_LEASE=1800;;
    miwa) MAC=02:42:6f:c6:15:00; NET=3; LOW=100; HIGH=199; EXPECTED_LEASE=43200;;
    *) echo 'Unknown client; Kugisaki belongs to question 6'; exit 1;;
esac
[ "$(cat /sys/class/net/eth0/address)" = "$MAC" ] || { echo 'Wrong eth0 MAC for selected client'; exit 1; }
field() { sed -n "s/^$1=//p" "$ROOT/lease.env"; }
owned_pid() {
    [ -f "$PIDFILE" ] || return 1
    PID=$(cat "$PIDFILE")
    case "$PID" in ''|*[!0-9]*) return 1;; esac
    [ -r "/proc/$PID/cmdline" ] || return 1
    tr '\000' ' ' < "/proc/$PID/cmdline" | grep -Fq '/root/no2-5-udhcpc-hook.sh'
}
verify() {
    [ -s "$ROOT/lease.env" ]
    owned_pid
    IP=$(field IP)
    LAST=${IP##*.}
    [ "${IP%.*}" = "192.229.$NET" ]
    [ "$LAST" -ge "$LOW" ]
    [ "$LAST" -le "$HIGH" ]
    [ "$(field MASK)" = 24 ]
    [ "$(field SUBNET)" = 255.255.255.0 ]
    [ "$(field BROADCAST)" = "192.229.$NET.255" ]
    [ "$(field ROUTERS)" = "192.229.$NET.1" ]
    [ "$(field DNS)" = '192.229.1.2 192.229.1.3' ]
    [ "$(field SEARCH_OPTION)" = K46.com ]
    [ "$(field LEASE)" = "$EXPECTED_LEASE" ]
    [ "$(field SERVER_ID)" = 192.229.4.10 ]
    ip -o -4 addr show dev eth0 | grep -Fq " $IP/24 "
    ip -4 route get 1.1.1.1 | grep -Fq "via 192.229.$NET.1 dev eth0"
    grep -q '^search K46.com$' /etc/resolv.conf
    grep -q '^nameserver 192.229.1.2$' /etc/resolv.conf
    grep -q '^nameserver 192.229.1.3$' /etc/resolv.conf
    cat "$ROOT/lease.env"
    ip -4 -br addr
    ip -4 route
    cat /etc/resolv.conf
    ping -c 3 -i 0.2 -W 3 "192.229.$NET.1"
    ping -c 3 -i 0.2 -W 3 192.229.4.10
    ping -c 3 -i 0.2 -W 3 1.1.1.1
    printf 'RESULT: %s DHCP_CLIENT PASS\n' "$NODE"
}
if [ "$MODE" = --verify ]; then verify; exit; fi
if [ "$MODE" = --renew ]; then
    owned_pid
    OLD=$(field SEQ)
    kill -USR1 "$PID"
    COUNT=0
    while [ "$COUNT" -lt 20 ]; do
        sleep 1
        if [ -s "$ROOT/lease.env" ] && [ "$(field SEQ)" -gt "$OLD" ]; then verify; exit; fi
        COUNT=$((COUNT+1))
    done
    echo 'Renew did not complete'; exit 1
fi
mkdir -p "$ROOT" /run
if [ "$MODE" = apply ] && [ ! -d "$ROOT/backup-before" ]; then
    mkdir -p "$ROOT/backup-before"
    cp -p /etc/network/interfaces "$ROOT/backup-before/interfaces"
    cp -p /etc/resolv.conf "$ROOT/backup-before/resolv.conf"
    [ ! -f /root/init.sh ] || cp -p /root/init.sh "$ROOT/backup-before/init.sh"
fi
cat > /root/no2-5-udhcpc-hook.sh <<'CLIENT_HOOK'
#!/bin/sh
# DHCP options are supplied by udhcpc as environment variables.
set -eu
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ROOT=/root/no2-5
mkdir -p "$ROOT"
[ "${interface:-}" = eth0 ] || exit 1
case "${1:-}" in
    deconfig)
        ip -4 addr flush dev eth0 scope global
        while ip -4 route del default dev eth0 2>/dev/null; do :; done
        : > "$ROOT/lease.env"
        printf 'EVENT=deconfig\n' >> "$ROOT/events.log"
        ;;
    bound|renew)
        [ -n "${ip:-}" ]
        [ -n "${subnet:-}" ]
        [ -n "${router:-}" ]
        [ -n "${dns:-}" ]
        ip link set dev eth0 up
        ip -4 addr replace "$ip/${mask:-24}" broadcast "${broadcast:-+}" dev eth0
        while ip -4 route del default dev eth0 2>/dev/null; do :; done
        for GW in $router; do ip -4 route replace default via "$GW" dev eth0; break; done
        SEARCH=${search:-${domain:-}}
        {
            [ -z "$SEARCH" ] || printf 'search %s\n' "$SEARCH"
            for NS in $dns; do printf 'nameserver %s\n' "$NS"; done
        } > "$ROOT/resolv.conf"
        cat "$ROOT/resolv.conf" > /etc/resolv.conf
        SEQ=0
        if [ -f "$ROOT/event-seq" ]; then SEQ=$(cat "$ROOT/event-seq"); fi
        case "$SEQ" in ''|*[!0-9]*) SEQ=0;; esac
        SEQ=$((SEQ+1))
        printf '%s\n' "$SEQ" > "$ROOT/event-seq"
        {
            printf 'EVENT=%s\nSEQ=%s\n' "$1" "$SEQ"
            printf 'IP=%s\nMASK=%s\nSUBNET=%s\nBROADCAST=%s\n' "$ip" "${mask:-}" "$subnet" "${broadcast:-}"
            printf 'ROUTERS=%s\nDNS=%s\nDOMAIN=%s\nSEARCH=%s\nSEARCH_OPTION=%s\n' "$router" "$dns" "${domain:-}" "$SEARCH" "${search:-}"
            printf 'LEASE=%s\nSERVER_ID=%s\nRECEIVED_AT=%s\n' "${lease:-}" "${serverid:-}" "$(date +%s)"
        } > "$ROOT/lease.env.tmp"
        mv "$ROOT/lease.env.tmp" "$ROOT/lease.env"
        cat "$ROOT/lease.env" >> "$ROOT/events.log"
        printf '\n' >> "$ROOT/events.log"
        ;;
    leasefail|nak)
        printf 'EVENT=%s\n' "$1" >> "$ROOT/events.log"
        ;;
esac
CLIENT_HOOK
chmod 755 /root/no2-5-udhcpc-hook.sh
# Manual here avoids a second GNS-managed udhcpc. The root hook runs DHCP.
cat > /etc/network/interfaces <<'CLIENT_INTERFACES'
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet manual
# DHCP is managed by /root/no2-client.sh with a persistent renewal daemon.
CLIENT_INTERFACES
if [ "$MODE" = apply ]; then
    if [ ! -f /root/init.sh ]; then printf '#!/bin/sh\n' > /root/init.sh; fi
    if ! grep -q '^# BEGIN JARKOM-NO2-5-CLIENT$' /root/init.sh; then
        printf '\n# BEGIN JARKOM-NO2-5-CLIENT\nsh /root/no2-client.sh %s --boot >> /root/no2-5-client-boot.log 2>&1\n# END JARKOM-NO2-5-CLIENT\n' "$NODE" >> /root/init.sh
    fi
    chmod 755 /root/init.sh /root/no2-client.sh
    sh -n /root/init.sh
fi
# Stop only udhcpc processes owning eth0, never a daemon on another interface.
for PF in "$PIDFILE" /var/run/udhcpc.eth0.pid; do
    if [ -f "$PF" ]; then
        PID=$(cat "$PF")
        case "$PID" in ''|*[!0-9]*) continue;; esac
        if [ -r "/proc/$PID/cmdline" ]; then
            CMD=$(tr '\000' ' ' < "/proc/$PID/cmdline")
            if printf '%s' "$CMD" | grep -q 'udhcpc' && printf '%s' "$CMD" | grep -Eq '(^| )-i eth0( |$)'; then
                kill "$PID" || true
                sleep 1
            fi
        fi
        rm -f "$PF"
    fi
done
: > "$ROOT/lease.env"
ip link set dev eth0 up
udhcpc -i eth0 -s /root/no2-5-udhcpc-hook.sh -p "$PIDFILE" -b -R -t 5 -T 1 -A 2 -O search -x lease:3600 -x "hostname:$NODE" > "$ROOT/udhcpc.log" 2>&1
COUNT=0
while [ "$COUNT" -lt 25 ]; do
    if [ -s "$ROOT/lease.env" ] && owned_pid; then verify; exit; fi
    sleep 1
    COUNT=$((COUNT+1))
done
cat "$ROOT/udhcpc.log"
echo 'DHCP lease was not received'; exit 1
CLIENT_SCRIPT
        sh /root/no2-client.sh "$NODE" "${2:-apply}"
        ;;
    *) echo 'Soal 5 dijalankan pada tengen atau salah satu dari tujuh client'; exit 1;;
esac
