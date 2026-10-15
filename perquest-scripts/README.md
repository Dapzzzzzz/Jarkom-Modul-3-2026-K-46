# Script per soal - Modul 3 K-46 (prefix 192.234)

Struktur: `soal_N/<node>.sh`. Setiap file berdiri sendiri dan hanya berisi konfigurasi node tersebut.
Salin isinya ke `/root/soal_N.sh` pada node yang bersangkutan, lalu jalankan `sh /root/soal_N.sh`.

| Soal | File | Node |
| --- | --- | --- |
| 1 | `soal_1/jichi.sh` | jichi (WAN, gateway Network 1-4, forwarding, NAT) |
| 1 | `soal_1/<node>.sh` | utahime, shoko, gojo, geto, maki, panda, nanami, todo, kirara, yaga, inumaki, tengen (IP statis) |
| 2 | `soal_2/tengen.sh` | isc-dhcp-server, scope Network 2 dan 3 |
| 3 | `soal_3/jichi.sh` | DHCP relay |
| 4 | `soal_4/tengen.sh` | class MAC dan dua pool Network 2 |
| 5 | `soal_5/tengen.sh` | pool/lease Network 3, DNS, domain-search |
| 5 | `soal_5/<client>.sh` | itadori, fushiguro, zenin, okkotsu, ino, kusakabe, miwa (DHCP client) |
| 6 | `soal_6/tengen.sh` | static lease kugisaki -> 192.234.3.99 |
| 6 | `soal_6/kugisaki.sh` | kugisaki (DHCP client) |
| 7 | `soal_7/tengen.sh` | cocokkan `dhcpd.leases` dengan kebijakan pool, cek tabrakan |
| 7 | `soal_7/<client>.sh` | 8 client: periksa IP, mask, broadcast, gateway, DNS, domain-search |
| 8 | `soal_8/tengen.sh` + `soal_8/miwa.sh` | tcpdump di tengen (40 detik), miwa meminta lease baru; lihat DORA dan giaddr |
| 9 | `soal_9/jichi.sh` + `soal_9/itadori.sh` | `stop`/`start` relay di jichi; itadori meminta lease (gagal lalu berhasil) |
| 10 | `soal_10/tengen.sh`, `soal_10/jichi.sh`, `soal_10/<client>.sh` | autostart dan verifikasi setelah restart node |
| 11 | `soal_11/utahime.sh` | DNS Master BIND9 `jujutsu.K46.com`, allow-transfer/also-notify ke shoko |
| 11 | `soal_11/shoko.sh` | DNS Slave, menyalin zona dari utahime |
| 11 | `soal_11/itadori.sh` | dig ke kedua server, bandingkan serial |
| 12 | `soal_12/utahime.sh` | A `jujutsu.K46.com` -> gojo, CNAME `www`, zona PTR `1.234.192.in-addr.arpa`, forwarder 192.168.122.1 |
| 12 | `soal_12/shoko.sh` | slave zona PTR, forwarder yang sama |
| 12 | `soal_12/itadori.sh` | dig A/CNAME/PTR, ping google.com |
| 13 | `soal_13/yaga.sh` | MariaDB master: log-bin, server-id 1, `db_shibuya_K46.request_logs`, user remote Network 4 |
| 13 | `soal_13/inumaki.sh` | MariaDB slave: server-id 2, `CHANGE MASTER TO` ke yaga |

Urutan: 1 (semua node) -> 2 -> 3 -> 4 -> 5 -> 6. Config `dhcpd.conf` bersifat kumulatif: soal 4 memuat isi soal 2, soal 5 memuat isi soal 4, soal 6 memuat isi soal 5.

- Soal 8: jalankan `sh /root/soal_8.sh` di tengen, lalu dalam 40 detik jalankan `sh /root/soal_8.sh` di miwa.
- Soal 9: urutan jichi `stop` -> itadori -> jichi `start` -> itadori.
- Soal 10: jalankan di tengen dan jichi, restart node dari GNS3 dengan **Stop lalu Start** (bukan Reload: pada GNS3 3.0.6 ini Reload membuat node tidak selesai booting), lalu jalankan lagi.
- Soal 11: utahime dulu, lalu shoko. Uji sinkronisasi: `sh /root/soal_11.sh naikkan` di utahime (serial +1), lalu `sh /root/soal_11.sh` di itadori.
- Soal 13: yaga dulu, lalu inumaki. Uji: `sh /root/soal_13.sh uji` di yaga (insert baris), lalu `sh /root/soal_13.sh cek` di inumaki.
  Kredensial: replikasi `repl`/`repl46`, akses aplikasi `shibuya`/`shibuya46` dari 192.234.4.0/24.
Autostart ditambahkan ke `/root/init.sh`.

Pool dan durasi:

| Client | Pool | Lease |
| --- | --- | --- |
| itadori, fushiguro | 192.234.2.10-35 | 3600 s |
| zenin, okkotsu | 192.234.2.70-95 | 3600 s |
| ino, kusakabe | 192.234.3.10-89 | 1800 s |
| miwa | 192.234.3.100-199 | 43200 s |
