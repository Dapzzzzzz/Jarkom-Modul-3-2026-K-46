# Jarkom Modul 3 K-46

| 	Nama              	| NRP        | Pembagian Pengerjaaan  |
| ---------------------	| ---------- | ---------------------- |
| Hendra Manudinata 	| 5027251051 | Soal 6 - 13            |
| Daffa Rifqi As Shidiq	| 5027251038 | Soal 1 - 5 dan 14 - 20 |

* Kelompok: K-46
* Prefix IP: 192.234.x.x

---

## Soal 1
Ketika Curtain menutup Shibuya, jalur komunikasi antar zona Jujutsu High terputus. Pulihkan konektivitas dasar dengan mengonfigurasi jichi: eth0 memperoleh WAN dari NAT, sedangkan eth1–eth4 menjadi gateway Network 1–4 sesuai tabel pemetaan. Aktifkan IPv4 forwarding dan source NAT, lalu tetapkan IP statis host infrastruktur sesuai tabel spesifikasi. Buktikan konektivitas setiap host ke gateway dan akses eksternal dari host yang relevan.

### Jawaban dan Penjelasan

#### 1. Konfigurasi `jichi`

Node `jichi` berfungsi sebagai router utama yang menghubungkan empat jaringan. Interface `eth0` menggunakan DHCP dari NAT, sedangkan `eth1` sampai `eth4` menjadi gateway masing-masing network.

```bash
auto eth0
iface eth0 inet dhcp

auto eth1
iface eth1 inet static
    address 192.234.1.1
    netmask 255.255.255.0

auto eth2
iface eth2 inet static
    address 192.234.2.1
    netmask 255.255.255.0

auto eth3
iface eth3 inet static
    address 192.234.3.1
    netmask 255.255.255.0

auto eth4
iface eth4 inet static
    address 192.234.4.1
    netmask 255.255.255.0
```

Selanjutnya, dilakukan konfigurasi IPv4 forwarding dan source NAT.

```bash
sysctl -w net.ipv4.ip_forward=1

iptables -t nat -C POSTROUTING -s 192.234.0.0/16 -o eth0 -j MASQUERADE 2>/dev/null ||
    iptables -t nat -A POSTROUTING -s 192.234.0.0/16 -o eth0 -j MASQUERADE
```

IPv4 forwarding memungkinkan `jichi` meneruskan paket antarjaringan. Sementara itu, `MASQUERADE` digunakan untuk mengubah IP sumber paket menjadi IP WAN milik `jichi` agar node internal dapat mengakses jaringan eksternal. Opsi `-C` digunakan untuk memeriksa keberadaan aturan NAT sebelum menambahkannya dengan `-A`.

#### 2. Konfigurasi Node Infrastruktur

Node `utahime`, `shoko`, `gojo`, `tengen`, `geto`, `maki`, `panda`, `nanami`, `todo`, `kirara`, `yaga`, dan `inumaki` menggunakan pola konfigurasi yang sama. Perbedaannya hanya terdapat pada IP address dan gateway sesuai network masing-masing.

Sebagai contoh, berikut konfigurasi pada node `tengen`:

```bash
auto eth0
iface eth0 inet static
    address 192.234.4.10
    netmask 255.255.255.0
    gateway 192.234.4.1
    up echo "nameserver 192.168.122.1" > /etc/resolv.conf
```

Konfigurasi tersebut menetapkan IP statis, subnet mask `/24`, gateway menuju `jichi`, dan DNS sementara. Node pada Network 1 menggunakan gateway `192.234.1.1`, sedangkan node pada Network 4 menggunakan gateway `192.234.4.1`.

### Verifikasi

#### 1. Verifikasi Konfigurasi `jichi`

```bash
ip -4 -br addr
sysctl net.ipv4.ip_forward
iptables -t nat -S POSTROUTING
```

Berdasarkan hasil pengujian, interface `eth1` sampai `eth4` telah memiliki IP sesuai pembagian network. Nilai `net.ipv4.ip_forward = 1` menunjukkan bahwa IPv4 forwarding aktif, sedangkan aturan `MASQUERADE` menunjukkan bahwa source NAT telah dikonfigurasi.

<img width="769" height="400" alt="image" src="https://github.com/user-attachments/assets/a5e7e6e7-0896-452a-a373-84e26f9d9c07" />

#### 2. Verifikasi Konektivitas Node `tengen`

```bash
ping -c 3 192.234.4.1
ping -c 3 8.8.8.8
```

Pengujian dilakukan dari node `tengen` menuju gateway `192.234.4.1` dan IP eksternal `8.8.8.8`. Kedua pengujian menghasilkan 3 paket terkirim, 3 paket diterima, dan 0% packet loss. Hal ini membuktikan bahwa `tengen` dapat terhubung ke gateway dan mengakses jaringan eksternal melalui `jichi`.

![Uploading image.png…]()


## Soal 2

```
Tengen, penjaga pusat distribusi di Data Center, harus mengambil alih
pengalokasian alamat bagi wilayah yang membutuhkan konfigurasi dinamis.
Konfigurasikan isc-dhcp-server pada [PREFIX IP].4.10. Deklarasikan
Network 4 ([PREFIX IP].4.0/24) sebagai subnet lokal tanpa pool dinamis,
lalu siapkan scope DHCP untuk Network 2 ([PREFIX IP].2.0/24) dan Network
3 ([PREFIX IP].3.0/24). Validasi konfigurasi dan pastikan service aktif
tanpa error “No subnet declaration”.
```

## Soal 3

```
Permintaan alamat dari Divisi A dan Divisi B tidak dapat menyeberangi
subnet secara langsung. Konfigurasikan jichi sebagai DHCP Relay menuju
tengen ([PREFIX IP].4.10), menggunakan eth2 untuk Network 2 dan eth3
untuk Network 3. Buktikan bahwa client dari kedua subnet berhasil
memperoleh lease melalui relay.
```

## Soal 4

```
Agar tim Dev dan Support di Divisi A menerima jatah alamat yang berbeda,
atur dua pool DHCP pada Network 2. Tetapkan Pool 1 ([PREFIX
IP].2.10–[PREFIX IP].2.35) untuk itadori dan fushiguro, serta Pool 2
([PREFIX IP].2.70–[PREFIX IP].2.95) untuk zenin dan okkotsu. Rentang
[PREFIX IP].2.36–[PREFIX IP].2.69 tidak boleh dialokasikan. Karena
seluruh client berada pada subnet yang sama, gunakan DHCP class
berdasarkan MAC Address atau Client ID untuk memisahkan kedua kelompok.
```

## Soal 5

```
Setiap tim lapangan memiliki durasi operasi yang berbeda. Pada Network
3, berikan short lease 30 menit (1800 detik) kepada ino dan kusakabe,
serta long lease 12 jam (43200 detik) kepada miwa. Gunakan pool short
lease [PREFIX IP].3.10–[PREFIX IP].3.89 dan pool long lease [PREFIX
IP].3.100–[PREFIX IP].3.199. Sesuaikan default-lease-time dan
max-lease-time untuk setiap kelas client. Berikan pula DHCP options
berupa DNS [PREFIX IP].1.2 dan [PREFIX IP].1.3, serta domain-search
<xxxx>.com.
```

## Soal 6

```
Kugisaki ditetapkan sebagai personel VIP yang harus mempertahankan
alamat yang sama setiap kali terhubung. Buat DHCP static lease
berdasarkan MAC Address client tersebut dengan fixed address [PREFIX
IP].3.99. Pastikan alamat ini berada di luar seluruh pool dinamis,
validasi konfigurasi server, lalu renew lease pada client. Buktikan
bahwa alamat yang diterima sesuai dengan reservasi.
```

Kugisaki harus selalu menerima alamat `192.234.3.99`. Caranya, di `dhcpd.conf`
tengen ditambahkan deklarasi `host` yang mengikat MAC Address kugisaki ke alamat
tetap:

```
...
# Kugisaki (VIP): alamat tetap berdasarkan MAC, di luar semua pool dinamis
host kugisaki {
  hardware ethernet 02:42:6b:21:47:00;
  fixed-address 192.234.3.99;
}
...
```

Lalu, kugisaki melakukan restart koneksi LAN untuk me-refresh lease:

```
# Renew lease
$ pkill udhcpc 2>/dev/null
$ ip addr flush dev eth0
$ ifdown eth0 2>/dev/null
$ ifup eth0

# Bukti: alamat harus 192.234.3.99
$ ip -4 -br addr show eth0
$ ip route | grep default
$ cat /etc/resolv.conf
```

## Soal 7

```
Setelah aturan alokasi diterapkan, pastikan setiap client menerima
konfigurasi jaringan sesuai wilayahnya: subnet mask 255.255.255.0 (/24),
gateway dan broadcast address yang benar, DNS [PREFIX IP].1.2 serta
[PREFIX IP].1.3, dan domain-search yang ditentukan. Periksa IP address
dan routing seluruh client Divisi A dan Divisi B, kemudian cocokkan
lease dengan /var/lib/dhcp/dhcpd.leases pada tengen. Pastikan tidak ada
alamat yang bertabrakan atau berada di luar kebijakan pool.
```

Soal ini tidak mengubah konfigurasi, hanya memverifikasi hasil soal 2–6 dari
dua sisi.

| Pemeriksaan | Nilai yang diharapkan |
| --- | --- |
| IP | dalam pool client (mis. itadori `192.234.2.10–35`) |
| Subnet mask | `/24` |
| Broadcast | `192.234.<net>.255` |
| Gateway | `192.234.<net>.1` (interface jichi) |
| DNS | `192.234.1.2` dan `192.234.1.3` di `/etc/resolv.conf` |
| Domain search | `search K46.com` |
| Konektivitas | ping ke gateway dan ke tengen `192.234.4.10` |

Langkah:

1. Baca `/var/lib/dhcp/dhcpd.leases`, mengambil lease berstatus `active`,
   lalu menamai client berdasarkan MAC Address.
2. Periksa bahwa setiap IP berada di salah satu pool yang diizinkan.
3. Periksa tabrakan: tidak ada IP yang muncul dua kali dan tidak ada MAC
   yang memegang lebih dari satu lease.

## Soal 8

```
Sebelum Curtain dibuka kembali, buktikan bahwa proses pemberian alamat
berjalan sesuai protokol. Lakukan packet capture saat salah satu client
Network 2 atau Network 3 meminta lease baru. Gunakan tcpdump pada tengen
atau jalur menuju Data Center untuk menunjukkan urutan DHCPDISCOVER →
DHCPOFFER → DHCPREQUEST → DHCPACK. Identifikasi alamat server, alamat
yang diberikan, lease time, dan field giaddr. Pastikan nilai giaddr
sesuai dengan interface jichi yang menerima request dari subnet client.
```

Pertukaran DHCP (Discover-Offer-Request-Ack / DORA) direkam dengan `tcpdump` di tengen, sementara miwa
(Network 3) meminta lease baru. Pertama, tengen merekam paket DHCP selama 40
detik:

```
# Install tcpdump jika belum ada
$ apt-get update && apt-get install -y tcpdump

# Capture paket DHCP (port 67/68) selama 40 detik
$ timeout 40 tcpdump -i eth0 -n -vv -l 'udp and (port 67 or port 68)' > /root/soal_8.log 2>&1 &
```

Selama capture berjalan, miwa melepas lease lama dan meminta lease baru:

```
$ pkill udhcpc 2>/dev/null
$ ip addr flush dev eth0
$ ifdown eth0 2>/dev/null
$ ifup eth0
```

Setelah capture selesai, tampilkan urutan pesan dan field yang diminta:

```
# Urutan pesan
$ grep -E 'DHCP-Message' /root/soal_8.log

# Server, alamat yang diberikan, lease time, giaddr
$ grep -E 'Server-ID|Your-IP|Lease-Time|Gateway-IP|Client-Ethernet' /root/soal_8.log
```

| Field | Nilai yang diharapkan |
| --- | --- |
| Urutan pesan | DHCPDISCOVER → DHCPOFFER → DHCPREQUEST → DHCPACK |
| Server-ID | `192.234.4.10` (tengen) |
| Your-IP | dalam pool long lease `192.234.3.100–199` |
| Lease-Time | `43200` detik |
| Gateway-IP (giaddr) | `192.234.3.1` (eth3 jichi) |

giaddr bernilai `192.234.3.1` karena request miwa diterima jichi lewat eth3
(Network 3), lalu diteruskan relay ke tengen. Dari giaddr inilah tengen tahu
subnet dan pool mana yang harus dipakai.

## Soal 9

```
Sebuah gangguan memutus jalur relay dan membuat permintaan alamat tidak
sampai ke Data Center. Hentikan service DHCP Relay pada jichi, lalu
paksa salah satu client di Network 2 atau Network 3 meminta lease baru
dan catat gejalanya. Pulihkan service relay, ulangi permintaan DHCP,
lalu buktikan bahwa client kembali memperoleh alamat dari pool yang
benar dengan gateway semula.
```

Pertama, matikan DHCP Relay di jichi:

```
$ service isc-dhcp-relay stop

# Bukti: proses dhcrelay sudah tidak ada
$ pgrep dhcrelay
```

Lalu, itadori melepas lease lama dan mencoba meminta lease baru (3 kali
percobaan, jeda 2 detik):

```
$ pkill udhcpc 2>/dev/null
$ ip addr flush dev eth0
$ udhcpc -i eth0 -n -q -t 3 -T 2
```

Gejalanya: DHCPDISCOVER dari itadori hanya ber-broadcast di Network 2 dan
tidak pernah sampai ke tengen, sehingga `udhcpc` gagal dan itadori tidak
mendapat IP.

Setelah itu, pulihkan relay di jichi:

```
$ service isc-dhcp-relay start

# Bukti: proses dhcrelay berjalan kembali
$ ps -eo args | grep '[d]hcrelay'
```

Jalankan ulang permintaan DHCP di itadori. Kali ini lease berhasil diperoleh,
lalu daemon DHCP client dinyalakan kembali:

```
$ udhcpc -i eth0 -n -q -t 3 -T 2
$ ifdown eth0 2>/dev/null
$ ifup eth0

# Bukti: IP dalam Pool 1 (192.234.2.10-35), gateway 192.234.2.1
$ ip -4 -br addr show eth0
$ ip route | grep default
```

## Soal 10

```
Setelah gangguan Shibuya tertangani, pastikan pemulihan bertahan setelah
restart. Aktifkan autostart DHCP Server pada tengen dan DHCP Relay pada
jichi, lalu restart kedua node. Verifikasi status layanan, IP, gateway,
lease, dan konektivitas client Network 2–3. Pastikan kebijakan Pool 1,
Pool 2, short lease, long lease, dan fixed address tetap berlaku.
```

Image node menjalankan `/root/init.sh` saat boot, jadi perintah start
service cukup didaftarkan ke file tersebut. Di tengen:

```
$ echo 'service isc-dhcp-server start >> /root/soal_2.log 2>&1' >> /root/init.sh
$ chmod 755 /root/init.sh
```

Di jichi:

```
$ echo 'service isc-dhcp-relay start >> /root/soal_3.log 2>&1' >> /root/init.sh
$ chmod 755 /root/init.sh
```

Forwarding dan NAT di jichi tidak perlu didaftarkan ke `init.sh`, karena
sudah dipasang lewat baris `up` pada eth0 di `/etc/network/interfaces`
(soal 1):

```
...
auto eth0
iface eth0 inet dhcp
    up sysctl -w net.ipv4.ip_forward=1
    up iptables -t nat -C POSTROUTING -s 192.234.0.0/16 -o eth0 -j MASQUERADE 2>/dev/null || iptables -t nat -A POSTROUTING -s 192.234.0.0/16 -o eth0 -j MASQUERADE
...
```

Lalu, restart tengen dan jichi dari GNS3 dengan **Stop** lalu **Start**
(bukan Reload, karena pada GNS3 3.0.6 node tidak selesai booting). Setelah
node menyala, periksa layanannya:

```
# tengen
$ service isc-dhcp-server status
$ dhcpd -4 -t -cf /etc/dhcp/dhcpd.conf
$ grep -E 'range|lease-time|fixed-address|allow members' /etc/dhcp/dhcpd.conf

# jichi
$ service isc-dhcp-relay status
$ sysctl net.ipv4.ip_forward
$ iptables -t nat -S POSTROUTING
$ ping -c 2 192.234.4.10
```

Terakhir, di setiap client Network 2 dan 3 dilakukan pemeriksaan yang sama
dengan soal 7, ditambah pengecekan bahwa daemon DHCP client masih berjalan:

```
$ pgrep udhcpc
```

Jika semua pemeriksaan lolos, kebijakan Pool 1, Pool 2, short lease, long
lease, dan fixed address terbukti tetap berlaku setelah restart.

## Soal 11

```
Utahime dan Shoko ditugaskan membangun sistem penamaan domain resmi agar
seluruh pos tidak perlu menghafal alamat IP mentah. Konfigurasikan BIND9
pada utahime sebagai DNS Master dan shoko sebagai DNS Slave untuk
mengelola domain jujutsu.<xxxx>.com. Atur SOA record, NS delegasi untuk
kedua server, dan terapkan allow-transfer dari Master ke Slave. Pastikan
file zona berhasil tersinkronisasi otomatis ke shoko saat nomor serial
di utahime dinaikkan, lalu buktikan dengan melakukan query dig ke kedua
server dari salah satu client.
```

Pertama, install BIND9 di utahime dan daftarkan zona `jujutsu.K46.com`
sebagai master. `allow-transfer` dan `also-notify` mengarah ke shoko
(`192.234.1.3`), sehingga shoko diberi tahu setiap kali zona berubah:

```
# /etc/bind/named.conf.local
zone "jujutsu.K46.com" {
    type master;
    file "/etc/bind/jujutsu/jujutsu.K46.com";
    allow-transfer { 192.234.1.3; };
    also-notify { 192.234.1.3; };
    notify yes;
};
```

Lalu, buat file zona berisi SOA dan NS untuk kedua server. Serial memakai
format waktu `YYMMDDhhmm`, sehingga selalu naik setiap kali script dijalankan
ulang. Record `uji` berisi nomor serial dan dipakai untuk mengecek
sinkronisasi:

```
# /etc/bind/jujutsu/jujutsu.K46.com
$TTL 604800
@       IN  SOA ns1.jujutsu.K46.com. root.jujutsu.K46.com. (
            <YYMMDDhhmm>  ; serial
            604800        ; refresh
            86400         ; retry
            2419200       ; expire
            604800 )      ; negative cache TTL

@       IN  NS  ns1.jujutsu.K46.com.
@       IN  NS  ns2.jujutsu.K46.com.
ns1     IN  A   192.234.1.2
ns2     IN  A   192.234.1.3
uji     IN  TXT "serial <YYMMDDhhmm>"
```

```
$ named-checkconf
$ named-checkzone jujutsu.K46.com /etc/bind/jujutsu/jujutsu.K46.com
$ service named restart
```

Di shoko, zona yang sama didaftarkan sebagai slave yang mengambil data dari
utahime:

```
# /etc/bind/named.conf.local
zone "jujutsu.K46.com" {
    type slave;
    masters { 192.234.1.2; };
    file "/var/lib/bind/jujutsu.K46.com";
};
```

```
$ named-checkconf
$ service named restart

# Bukti: file zona tersalin dari master
$ ls -la /var/lib/bind/
$ dig @127.0.0.1 jujutsu.K46.com SOA +short
```

Untuk menguji sinkronisasi otomatis, naikkan serial di utahime (+1), ubah
record `uji`, lalu reload zona. utahime akan mengirim NOTIFY ke shoko, dan
shoko langsung menarik zona yang baru:

```
$ sed -i "s/^\( *\)$OLD\( *; serial\)/\1$NEW\2/" /etc/bind/jujutsu/jujutsu.K46.com
$ sed -i "s/^uji .*/uji     IN  TXT \"serial $NEW\"/" /etc/bind/jujutsu/jujutsu.K46.com
$ rndc reload jujutsu.K46.com
```

Terakhir, dari itadori lakukan query ke kedua server. Serial dan record `uji`
dari master dan slave harus sama:

```
$ dig @192.234.1.2 jujutsu.K46.com SOA +noall +answer
$ dig @192.234.1.3 jujutsu.K46.com SOA +noall +answer
$ dig @192.234.1.2 uji.jujutsu.K46.com TXT +noall +answer
$ dig @192.234.1.3 uji.jujutsu.K46.com TXT +noall +answer
```

## Soal 12

```
Peta domain harus memetakan pintu masuk utama dan tetap bisa mencari
alamat di luar kawasan Shibuya. Pada utahime, buat A record
jujutsu.<xxxx>.com yang mengarah ke gojo, serta CNAME www yang merujuk
ke domain utama tersebut. Buat pula Reverse DNS (zona PTR) untuk melacak
IP gojo kembali ke domain resminya, dan aktifkan fitur DNS Forwarder
pada BIND9 mengarah ke IP gateway internet (192.168.122.1). Uji dari
client dengan dig untuk mengecek CNAME, PTR, dan buktikan client tetap
bisa melakukan ping ke domain internet seperti google.com.
```

Pertama, aktifkan forwarder di utahime. Query untuk domain di luar zona
lokal (misalnya `google.com`) diteruskan ke `192.168.122.1`, dan recursion
diizinkan untuk seluruh jaringan internal:

```
# /etc/bind/named.conf.options
options {
    directory "/var/cache/bind";
    forwarders { 192.168.122.1; };
    allow-query { any; };
    allow-recursion { 127.0.0.1; 192.234.0.0/16; };
    dnssec-validation no;
    listen-on { any; };
    listen-on-v6 { none; };
};
```

Lalu, tambahkan zona reverse `1.234.192.in-addr.arpa` di samping zona
`jujutsu.K46.com` yang sudah ada, dengan transfer ke shoko seperti soal 11:

```
# /etc/bind/named.conf.local
...
zone "1.234.192.in-addr.arpa" {
    type master;
    file "/etc/bind/jujutsu/1.234.192.in-addr.arpa";
    allow-transfer { 192.234.1.3; };
    also-notify { 192.234.1.3; };
    notify yes;
};
```

Pada zona `jujutsu.K46.com`, tambahkan A record yang mengarah ke gojo
(`192.234.1.4`) dan CNAME `www`. Serial dinaikkan agar shoko ikut
memperbarui zonanya:

```
# /etc/bind/jujutsu/jujutsu.K46.com
...
@       IN  A      192.234.1.4
www     IN  CNAME  jujutsu.K46.com.
...
```

Zona reverse berisi PTR yang memetakan `192.234.1.4` kembali ke
`jujutsu.K46.com`:

```
# /etc/bind/jujutsu/1.234.192.in-addr.arpa
...
@       IN  NS     ns1.jujutsu.K46.com.
@       IN  NS     ns2.jujutsu.K46.com.
4       IN  PTR    jujutsu.K46.com.
```

```
$ named-checkconf
$ named-checkzone jujutsu.K46.com /etc/bind/jujutsu/jujutsu.K46.com
$ named-checkzone 1.234.192.in-addr.arpa /etc/bind/jujutsu/1.234.192.in-addr.arpa
$ service named restart
```

Di shoko, `named.conf.options` diisi forwarder yang sama, karena client juga
memakai shoko sebagai DNS kedua. Zona reverse ditambahkan sebagai slave:

```
# /etc/bind/named.conf.local
...
zone "1.234.192.in-addr.arpa" {
    type slave;
    masters { 192.234.1.2; };
    file "/var/lib/bind/1.234.192.in-addr.arpa";
};
```

Terakhir, uji dari itadori:

```
# A record dan CNAME
$ dig jujutsu.K46.com A +noall +answer
$ dig www.jujutsu.K46.com +noall +answer

# PTR
$ dig -x 192.234.1.4 +noall +answer

# Lewat DNS Slave
$ dig @192.234.1.3 www.jujutsu.K46.com +short
$ dig @192.234.1.3 -x 192.234.1.4 +short

# Domain internet lewat forwarder
$ ping -c 3 google.com
```

## Soal 13

```
Kepala Sekolah Yaga dan Inumaki mendirikan database terpusat yang
redundan agar log aktivitas kutukan tetap aman tersimpan. Konfigurasikan
MariaDB pada yaga sebagai DB-Master dan inumaki sebagai DB-Slave. Buat
database db_shibuya_<xxxx> beserta tabel request_logs di Master,
aktifkan binary logging (log-bin, server-id), lalu hubungkan inumaki
sebagai Slave yang menyalin data secara realtime dengan CHANGE MASTER
TO. Berikan hak akses remote bagi seluruh node di Network 4, lalu
buktikan replikasi berhasil dengan memasukkan data baru di Master dan
memeriksa hasilnya di Slave.
```

Pertama, install MariaDB di yaga, lalu aktifkan binary log dengan
`server-id = 1`. `bind-address` diubah ke `0.0.0.0` agar bisa diakses dari
node lain:

```
# /etc/mysql/mariadb.conf.d/60-soal13.cnf
[mysqld]
bind-address  = 0.0.0.0
server-id     = 1
log-bin       = /var/log/mysql/mysql-bin
binlog_format = ROW
```

```
$ service mariadb restart
```

Lalu, buat database `db_shibuya_K46` dan tabel `request_logs`, user replikasi
untuk inumaki, serta user aplikasi untuk seluruh Network 4
(`192.234.4.%`):

```sql
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

-- Akses remote untuk seluruh node Network 4
CREATE USER IF NOT EXISTS 'shibuya'@'192.234.4.%' IDENTIFIED BY 'shibuya46';
GRANT ALL PRIVILEGES ON db_shibuya_K46.* TO 'shibuya'@'192.234.4.%';
FLUSH PRIVILEGES;
```

```
# Bukti
$ mysql -e "SHOW VARIABLES WHERE Variable_name IN ('server_id','log_bin','bind_address');"
$ mysql -e "SHOW MASTER STATUS;"
```

Di inumaki, install MariaDB lalu set `server-id = 2`, relay log, dan
`read_only` agar data hanya berubah lewat replikasi:

```
# /etc/mysql/mariadb.conf.d/60-soal13.cnf
[mysqld]
bind-address = 0.0.0.0
server-id    = 2
relay-log    = /var/log/mysql/relay-bin
read_only    = 1
```

Lalu, hubungkan inumaki ke yaga dengan `CHANGE MASTER TO`. Replikasi dimulai
dari binlog pertama master (posisi 4), sehingga database dan tabel yang sudah
dibuat di yaga ikut tersalin:

```
# Ambil nama binlog pertama di master
$ mysql -h 192.234.4.8 -u repl -prepl46 -N -e "SHOW BINARY LOGS" | head -1
```

```sql
STOP SLAVE;
RESET SLAVE ALL;
DROP DATABASE IF EXISTS db_shibuya_K46;
CHANGE MASTER TO
    MASTER_HOST='192.234.4.8',
    MASTER_USER='repl',
    MASTER_PASSWORD='repl46',
    MASTER_LOG_FILE='<binlog pertama>',
    MASTER_LOG_POS=4;
START SLAVE;
```

```
# Bukti: Slave_IO_Running dan Slave_SQL_Running harus Yes
$ mysql -e "SHOW SLAVE STATUS\G" | grep -E 'Master_Host|Slave_IO_Running|Slave_SQL_Running|Seconds_Behind'
```

Terakhir, uji replikasi dengan memasukkan data baru di yaga:

```
$ mysql -e "INSERT INTO db_shibuya_K46.request_logs (client_ip, worker, method, path)
            VALUES ('10.0.0.1', 'yaga', 'TEST', '/uji-replikasi-$(date +%H%M%S)');"
```

Lalu periksa di inumaki. Baris yang baru dimasukkan di yaga harus langsung
muncul:

```
$ mysql -e "SELECT * FROM db_shibuya_K46.request_logs ORDER BY id DESC LIMIT 3;"
```

## Soal 14

```
Para penyihir lapangan bersiaga di Data Center sebagai pekerja backend
untuk memproses aplikasi. Pasang Nginx dan PHP-FPM pada maki dan panda
untuk menyajikan web frontend yang menampilkan hostname masing-masing.
Pada nanami, todo, dan kirara, siapkan layanan API yang mencatat log
request ke database yaga. Konfigurasikan virtual host agar worker
merespons domain layanan yang ditentukan. Batasi akses langsung dari
klien ke worker, web worker hanya menerima trafik melalui jalur proxy
web yang ditentukan, sedangkan worker API hanya menerima trafik melalui
geto. Uji bahwa akses langsung dari klien ditolak, sementara akses
melalui reverse proxy tetap berhasil.
```

## Soal 15

```
Geto bertugas mengendalikan pembagian beban request API di internal Data
Center agar server tidak tumbang bersamaan. Konfigurasikan Nginx pada
geto sebagai Load Balancer internal dengan upstream api_cluster yang
mengarahkan trafik ke nanami dan todo. Terapkan algoritma Weighted Round
Robin dengan bobot 3:1, di mana nanami menerima porsi beban tiga kali
lebih banyak daripada todo. Buktikan distribusi beban ini dengan
melakukan loop request berulang kali ke geto dari jaringan lokal Data
Center dan periksa rasio responnya.
```

## Soal 16

```
Gojo berdiri di perbatasan DMZ sebagai gerbang publik tunggal bagi
seluruh client dari luar maupun dalam. Konfigurasikan Nginx pada gojo
untuk melayani domain jujutsu.<xxxx>.com dan www.jujutsu.<xxxx>.com
menggunakan metode Path-Based Routing. Atur agar request root (/)
diteruskan secara Round Robin ke worker frontend (maki dan panda),
sedangkan request ke path /api diteruskan langsung ke geto. Uji dari
client Divisi A atau B bahwa akses ke web utama dibalas oleh Maki/Panda,
sedangkan akses ke /api diteruskan dan dijawab oleh Nanami/Todo.
```

## Soal 17

```
Komando pusat perlu mengetahui IP asli klien yang mengirimkan request
tanpa tertukar dengan IP proxy perantara. Konfigurasikan gojo dan geto
agar meneruskan informasi alamat klien melalui header X-Real-IP dan
X-Forwarded-For. Pastikan geto hanya mempercayai informasi alamat klien
yang diterima dari proxy terpercaya, dan skrip API menyimpan alamat
klien yang telah diverifikasi ke kolom client_ip pada tabel request_logs
di database yaga. Uji dengan mengirimkan request dari klien Network 2
dan Network 3 ke endpoint /api, kemudian periksa database untuk
memastikan alamat yang tercatat sesuai dengan IP klien asal, bukan IP
gojo atau geto.
```

## Soal 18

```
nanami dan todo merupakan worker API utama, sedangkan kirara disiapkan
sebagai worker cadangan. Konfigurasikan upstream api_cluster pada geto
agar kirara menjadi server backup, serta terapkan passive health check
dengan parameter max_fails=2 dan fail_timeout=5s pada worker API utama.
Pastikan kirara menjalankan layanan API yang kompatibel dengan endpoint
utama. Simulasikan gangguan dengan menghentikan layanan Nginx atau
layanan API pada nanami dan todo. Buktikan dari klien bahwa request ke
/api dialihkan ke kirara dan menghasilkan respons API yang valid tanpa
error 502 Bad Gateway.
```

## Soal 19

```
gojo bertugas mengoptimalkan layanan web sekaligus membatasi request
berlebihan. Konfigurasikan Nginx Proxy Caching untuk halaman web
frontend dengan masa berlaku cache 10 menit dan tambahkan header
X-Cache-Status. Terapkan rate limiting pada path /api dengan batas 10
request per detik per IP klien. Buktikan bahwa request ke halaman web
yang memenuhi syarat cache menghasilkan status MISS pada akses awal dan
HIT pada akses berikutnya. Uji rate limiting secara terpisah dengan
mengirimkan request beruntun ke /api, kemudian catat status respons yang
dihasilkan ketika batas terlampaui.
```

## Soal 20

```
Sebelum Curtain di Shibuya resmi dibuka, Kusakabe memimpin audit untuk
menguji kapasitas layanan. Dari terminal kusakabe, jalankan benchmark
menggunakan Apache Benchmark dengan parameter -n 600 -c 30 menuju
http://jujutsu.<xxxx>.com/. Catat Requests per Second (RPS), latensi,
dan jumlah request yang gagal. Lakukan pengujian tambahan pada endpoint
/api untuk mengamati efek rate limiting. Bandingkan hasil pengujian
baseline dengan hasil ketika rate limiting aktif, serta gunakan access
log gojo untuk membedakan kegagalan aplikasi, koneksi, dan request yang
ditolak oleh kebijakan rate limit.
```
