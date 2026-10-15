#!/bin/sh
# Soal 7
#   - tengen: cocokkan lease aktif di /var/lib/dhcp/dhcpd.leases dengan kebijakan pool.

LEASES=/var/lib/dhcp/dhcpd.leases

# Ambil lease aktif (IP dan MAC), lalu beri nama client berdasarkan MAC
echo "== Lease aktif (IP, MAC, client) =="
awk '
/^lease /{ip=$2}
/^ *binding state/{st[ip]=$3}
/hardware ethernet/{m=$3; sub(/;/,"",m); mac[ip]=m}
END{for(i in st) if(st[i]=="active;") print i, mac[i]}
' $LEASES | sort -V | while read IP MAC; do
    case "$MAC" in
        02:42:b1:2c:43:00) N=itadori;;   02:42:40:6b:23:00) N=fushiguro;;
        02:42:3b:3a:6b:00) N=zenin;;     02:42:35:6c:75:00) N=okkotsu;;
        02:42:b9:fd:f9:00) N=ino;;       02:42:4e:89:96:00) N=kusakabe;;
        02:42:6f:c6:15:00) N=miwa;;      *) N=?;;
    esac
    echo "$IP $MAC $N"
done > /root/soal_7.active
cat /root/soal_7.active

# Cek apakah setiap IP berada dalam pool yang diizinkan
echo "== Kebijakan pool =="
awk '
{ split($1,o,"."); n=o[3]; l=o[4]+0; ok=0
  if (n==2 && ((l>=10&&l<=35)||(l>=70&&l<=95))) ok=1
  if (n==3 && ((l>=10&&l<=89)||(l>=100&&l<=199))) ok=1
  print ($1 " " (ok ? "OK: dalam pool" : "ERR: di luar pool")) }
' /root/soal_7.active

# Cek tabrakan: IP atau MAC yang muncul lebih dari sekali
echo "== Tabrakan alamat =="
D1=$(awk '{print $1}' /root/soal_7.active | sort | uniq -d)
D2=$(awk '$2!="" {print $2}' /root/soal_7.active | sort | uniq -d)

if [ -z "$D1" ]; then
    echo "OK: tidak ada IP ganda"
else
    echo "ERR: IP ganda: $D1"
fi

if [ -z "$D2" ]; then
    echo "OK: tidak ada MAC dengan lebih dari satu lease"
else
    echo "ERR: MAC ganda: $D2"
fi

echo "Catatan: kugisaki (fixed-address 192.234.3.99) tidak dicatat di dhcpd.leases; periksa dari client."
