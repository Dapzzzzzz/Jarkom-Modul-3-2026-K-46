#!/bin/sh
# Soal 9
#   - jichi: matikan lalu pulihkan DHCP relay.
#   - Pemakaian: sh /root/soal_9.sh stop   (gangguan)
#                sh /root/soal_9.sh start  (pemulihan)

case "$1" in
    stop)
        service isc-dhcp-relay stop
        sleep 1

        # Pastikan proses dhcrelay sudah tidak ada
        if pgrep dhcrelay >/dev/null; then
            echo "ERR: relay masih berjalan"
        else
            echo "OK: relay mati"
        fi
        ;;
    start)
        service isc-dhcp-relay start
        sleep 1

        # Pastikan proses dhcrelay berjalan kembali
        if ps -eo args | grep '[d]hcrelay'; then
            echo "OK: relay hidup kembali"
        else
            echo "ERR: relay gagal dijalankan"
        fi
        ;;
    *)
        echo "Pemakaian: sh /root/soal_9.sh stop|start"
        exit 1
        ;;
esac
