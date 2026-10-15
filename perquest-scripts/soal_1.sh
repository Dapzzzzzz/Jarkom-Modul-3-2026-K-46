#!/bin/sh
# Soal 1: WAN NAT, gateway Network 1-4, forwarding/SNAT, IP statis infrastruktur.
# Prefix K-46: 192.229.x.x. Jalankan file ini pada node terkait.
# ==== NODE JICHI + HOST INFRASTRUKTUR (pilih otomatis dari hostname) ====
# Pemakaian: sh /root/no1.sh jichi [--verify|--boot]
# Host lain: ganti jichi dengan nama node pada tabel case di bawah.
set -eu
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
NODE=$(printf '%s' "${1:-$(hostname)}" | tr '[:upper:]' '[:lower:]')
MODE=${2:-apply}
PREFIX=192.229
DNS=192.168.122.1
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$*"; }
[ "$(id -u)" = 0 ] || fail 'Jalankan sebagai root'
case "$MODE" in apply|--boot|--verify) ;; *) fail 'Mode tidak dikenal';; esac
case "$NODE" in
    # ==== NODE JICHI ====
    jichi) IP=; GW=192.168.122.1 ;;
    # ==== NODE UTAHIME ====
    utahime) IP=$PREFIX.1.2 ;;
    # ==== NODE SHOKO ====
    shoko) IP=$PREFIX.1.3 ;;
    # ==== NODE GOJO ====
    gojo) IP=$PREFIX.1.4 ;;
    # ==== NODE GETO ====
    geto) IP=$PREFIX.4.2 ;;
    # ==== NODE MAKI ====
    maki) IP=$PREFIX.4.3 ;;
    # ==== NODE PANDA ====
    panda) IP=$PREFIX.4.4 ;;
    # ==== NODE NANAMI ====
    nanami) IP=$PREFIX.4.5 ;;
    # ==== NODE TODO ====
    todo) IP=$PREFIX.4.6 ;;
    # ==== NODE KIRARA ====
    kirara) IP=$PREFIX.4.7 ;;
    # ==== NODE YAGA ====
    yaga) IP=$PREFIX.4.8 ;;
    # ==== NODE INUMAKI ====
    inumaki) IP=$PREFIX.4.9 ;;
    # ==== NODE TENGEN ====
    tengen) IP=$PREFIX.4.10 ;;
    *) fail 'Nama node wajib: jichi/utahime/shoko/gojo/geto/maki/panda/nanami/todo/kirara/yaga/inumaki' ;;
esac
if [ "$NODE" != jichi ]; then GW=${IP%.*}.1; fi

write_interfaces() {
    {
        printf 'auto lo\niface lo inet loopback\n\n'
        if [ "$NODE" = jichi ]; then
            printf 'auto eth0\niface eth0 inet dhcp\n\n'
            for N in 1 2 3 4; do
                printf 'auto eth%s\niface eth%s inet static\n    address %s.%s.1\n    netmask 255.255.255.0\n\n' "$N" "$N" "$PREFIX" "$N"
            done
        else
            printf 'auto eth0\niface eth0 inet static\n    address %s\n    netmask 255.255.255.0\n    gateway %s\n    up printf "nameserver %s\\n" > /etc/resolv.conf\n' "$IP" "$GW" "$DNS"
        fi
    } > /etc/network/interfaces
}

static_address() {
    DEV=$1
    ADDR=$2
    ip link show dev "$DEV" >/dev/null || fail "Interface $DEV tidak tersedia"
    ip link set dev "$DEV" up
    # Hapus hanya alamat IPv4 lain di interface yang sedang dikonfigurasi.
    for OLD in $(ip -o -4 addr show dev "$DEV" scope global | awk '{print $4}'); do
        [ "$OLD" = "$ADDR/24" ] || ip addr del "$OLD" dev "$DEV"
    done
    ip addr replace "$ADDR/24" broadcast + dev "$DEV"
}

router_rules() {
    command -v iptables >/dev/null || fail 'iptables belum terpasang'
    mkdir -p /etc/sysctl.d
    printf 'net.ipv4.ip_forward=1\n' > /etc/sysctl.d/99-jarkom-no1.conf
    sysctl -w net.ipv4.ip_forward=1
    # MASQUERADE sesuai WAN DHCP. Tidak menghapus rule yang sudah ada.
    iptables -w 5 -t nat -C POSTROUTING -s "$PREFIX.0.0/16" -o eth0 -j MASQUERADE 2>/dev/null ||
        iptables -w 5 -t nat -A POSTROUTING -s "$PREFIX.0.0/16" -o eth0 -j MASQUERADE
    # Chain sendiri: routing antarsubnet dan trafik keluar/balik dari WAN.
    iptables -w 5 -nL JARKOM1_FWD >/dev/null 2>&1 || iptables -w 5 -N JARKOM1_FWD
    iptables -w 5 -C JARKOM1_FWD -s "$PREFIX.0.0/16" -d "$PREFIX.0.0/16" -j ACCEPT 2>/dev/null ||
        iptables -w 5 -A JARKOM1_FWD -s "$PREFIX.0.0/16" -d "$PREFIX.0.0/16" -j ACCEPT
    iptables -w 5 -C JARKOM1_FWD -s "$PREFIX.0.0/16" -o eth0 -j ACCEPT 2>/dev/null ||
        iptables -w 5 -A JARKOM1_FWD -s "$PREFIX.0.0/16" -o eth0 -j ACCEPT
    iptables -w 5 -C JARKOM1_FWD -i eth0 -d "$PREFIX.0.0/16" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null ||
        iptables -w 5 -A JARKOM1_FWD -i eth0 -d "$PREFIX.0.0/16" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -w 5 -C FORWARD -j JARKOM1_FWD 2>/dev/null || iptables -w 5 -I FORWARD 1 -j JARKOM1_FWD
}

boot_hook() {
    [ -f /root/no1.sh ] || fail 'Simpan script ini di /root/no1.sh terlebih dahulu'
    sh -n /root/no1.sh || fail 'Sintaks script tidak valid'
    chmod 755 /root/no1.sh
    if [ ! -f /root/init.sh ]; then printf '#!/bin/sh\n' > /root/init.sh; fi
    if ! grep -q '^# BEGIN JARKOM-NO1$' /root/init.sh; then
        printf '\n# BEGIN JARKOM-NO1\nsh /root/no1.sh %s --boot >> /root/no1-boot.log 2>&1\n# END JARKOM-NO1\n' "$NODE" >> /root/init.sh
    fi
    chmod 755 /root/init.sh
    sh -n /root/init.sh || fail 'Sintaks init.sh tidak valid'
}

verify() {
    printf '\n=== VERIFIKASI %s ===\n' "$NODE"
    ip -4 -br address
    ip -4 route
    if [ "$NODE" = jichi ]; then
        ip -o -4 addr show dev eth0 scope global | grep -q 'inet ' || fail 'WAN eth0 tidak mendapat IPv4'
        ip route show default | grep -q 'dev eth0' || fail 'Default route WAN tidak melalui eth0'
        for N in 1 2 3 4; do
            ip -o -4 addr show dev "eth$N" | grep -Fq " $PREFIX.$N.1/24 " || fail "Gateway eth$N salah"
            pass "eth$N=$PREFIX.$N.1/24"
        done
        [ "$(sysctl -n net.ipv4.ip_forward)" = 1 ] || fail 'IPv4 forwarding mati'
        iptables -w 5 -t nat -C POSTROUTING -s "$PREFIX.0.0/16" -o eth0 -j MASQUERADE || fail 'MASQUERADE tidak ada'
        iptables -w 5 -C FORWARD -j JARKOM1_FWD || fail 'Chain forwarding tidak terhubung'
        pass 'IPv4 forwarding dan MASQUERADE aktif'
    else
        ip -o -4 addr show dev eth0 | grep -Fq " $IP/24 " || fail "IP statis seharusnya $IP/24"
        ip -4 route get 1.1.1.1 | grep -Fq "via $GW dev eth0" || fail 'Gateway/default route salah'
        pass "IP $IP/24 dan gateway $GW"
    fi
    ping -c 3 -W 3 "$GW" || fail "Gateway $GW tidak merespons"
    pass 'Ping gateway'
    ping -c 3 -W 3 1.1.1.1 || fail 'Ping IP internet gagal'
    pass 'Ping IP internet 1.1.1.1'
    getent ahostsv4 google.com || fail 'Resolusi DNS eksternal gagal'
    pass 'DNS eksternal google.com'
    curl -fsS --connect-timeout 8 --max-time 20 http://deb.debian.org/debian/ -o /dev/null || fail 'HTTP internet gagal'
    pass 'HTTP internet deb.debian.org'
    printf 'RESULT: %s PASS\n' "$NODE"
}

if [ "$MODE" = --verify ]; then verify; exit 0; fi

if [ "$MODE" = apply ]; then
    # Salinan persisten yang dipanggil hook startup nomor 1.
    if ! cmp -s "$0" /root/no1.sh; then cp "$0" /root/no1.sh; fi
    BACKUP=/root/no1-backup-original
    if [ ! -d "$BACKUP" ]; then
        mkdir -p "$BACKUP"
        cp -p /etc/network/interfaces "$BACKUP/interfaces"
        cp -p /etc/resolv.conf "$BACKUP/resolv.conf"
        [ ! -f /root/init.sh ] || cp -p /root/init.sh "$BACKUP/init.sh"
        ip -4 addr > "$BACKUP/ip-address.txt"
        ip -4 route > "$BACKUP/ip-route.txt"
        if [ "$NODE" = jichi ]; then iptables-save > "$BACKUP/iptables-save.txt"; fi
    fi
fi

write_interfaces
if [ "$NODE" = jichi ]; then
    for N in 1 2 3 4; do static_address "eth$N" "$PREFIX.$N.1"; done
    ip link set dev eth0 up
    if ! ip -o -4 addr show dev eth0 scope global | grep -q 'inet '; then
        command -v ifup >/dev/null || fail 'WAN kosong dan ifup tidak tersedia; restart node dengan interfaces DHCP'
        ifup --force eth0
    fi
    ip -o -4 addr show dev eth0 scope global | grep -q 'inet ' || fail 'DHCP WAN gagal'
    router_rules
else
    static_address eth0 "$IP"
    ip route replace default via "$GW" dev eth0
fi
printf 'nameserver %s\n' "$DNS" > /etc/resolv.conf
if [ "$MODE" = apply ]; then boot_hook; fi
pass "Konfigurasi $NODE tersimpan; prefix $PREFIX"
if [ "$MODE" = apply ]; then verify; fi
