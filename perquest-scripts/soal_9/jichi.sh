#!/bin/sh
# Soal 9 - jichi: matikan lalu pulihkan DHCP relay.
# Simpan di /root/soal_9.sh. Pemakaian: sh /root/soal_9.sh stop   (gangguan)
#                                       sh /root/soal_9.sh start  (pemulihan)
case "$1" in
    stop)
        service isc-dhcp-relay stop
        sleep 1
        pgrep dhcrelay >/dev/null && echo "FAIL: relay masih berjalan" || echo "PASS: relay mati"
        ;;
    start)
        service isc-dhcp-relay start
        sleep 1
        ps -eo args | grep '[d]hcrelay' && echo "PASS: relay hidup kembali"
        ;;
    *) echo "Pemakaian: sh /root/soal_9.sh stop|start"; exit 1;;
esac
