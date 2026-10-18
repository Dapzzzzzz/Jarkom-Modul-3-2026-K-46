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

<img width="769" height="400" alt="image" src="https://github.com/user-attachments/assets/48c25264-8bb5-4c59-bce4-91fd5d258237" />

#### 2. Verifikasi Konektivitas Node `tengen`

```bash
ping -c 3 192.234.4.1
ping -c 3 8.8.8.8
```

Pengujian dilakukan dari node `tengen` menuju gateway `192.234.4.1` dan IP eksternal `8.8.8.8`. Kedua pengujian menghasilkan 3 paket terkirim, 3 paket diterima, dan 0% packet loss. Hal ini membuktikan bahwa `tengen` dapat terhubung ke gateway dan mengakses jaringan eksternal melalui `jichi`.

<img width="874" height="516" alt="image" src="https://github.com/user-attachments/assets/e833dbc0-72a2-49a5-b357-f6798eeab459" />


## Soal 2
Tengen, penjaga pusat distribusi di Data Center, harus mengambil alih pengalokasian alamat bagi wilayah yang membutuhkan konfigurasi dinamis. Konfigurasikan isc-dhcp-server pada [PREFIX IP].4.10. Deklarasikan Network 4 ([PREFIX IP].4.0/24) sebagai subnet lokal tanpa pool dinamis, lalu siapkan scope DHCP untuk Network 2 ([PREFIX IP].2.0/24) dan Network 3 ([PREFIX IP].3.0/24). Validasi konfigurasi dan pastikan service aktif tanpa error “No subnet declaration”.

### Jawaban dan Penjelasan

#### Konfigurasi `tengen`

Pada soal ini, node `tengen` dikonfigurasi sebagai DHCP Server dengan IP `192.234.4.10` menggunakan layanan `isc-dhcp-server`.

DHCP Server diatur agar berjalan pada interface `eth0`, kemudian dilakukan konfigurasi subnet melalui file `/etc/dhcp/dhcpd.conf`.

```bash
authoritative;
ddns-update-style none;
default-lease-time 3600;
max-lease-time 7200;

subnet 192.234.4.0 netmask 255.255.255.0 {
}

subnet 192.234.2.0 netmask 255.255.255.0 {
  option routers 192.234.2.1;
  option broadcast-address 192.234.2.255;
  range 192.234.2.10 192.234.2.35;
}

subnet 192.234.3.0 netmask 255.255.255.0 {
  option routers 192.234.3.1;
  option broadcast-address 192.234.3.255;
  range 192.234.3.10 192.234.3.89;
}
```

Network 4 dideklarasikan sebagai subnet lokal tanpa pool dinamis untuk mencegah error `No subnet declaration`. Sementara itu, Network 2 memperoleh rentang IP `192.234.2.10–192.234.2.35` dan Network 3 memperoleh rentang IP `192.234.3.10–192.234.3.89`. Durasi lease default diatur selama 3600 detik dengan maksimum 7200 detik.

### Verifikasi

Verifikasi dilakukan pada node `tengen` menggunakan perintah berikut:

```bash
dhcpd -4 -t -cf /etc/dhcp/dhcpd.conf
service isc-dhcp-server status
```

Berdasarkan hasil pengujian, konfigurasi DHCP berhasil divalidasi tanpa error dan layanan `isc-dhcp-server` menunjukkan status `dhcpd is running`. Hal ini membuktikan bahwa DHCP Server telah dikonfigurasi dan berjalan dengan baik.

<img width="777" height="325" alt="image" src="https://github.com/user-attachments/assets/c77bbcf9-6893-4fad-a417-b24440b57d99" />


## Soal 3
Permintaan alamat dari Divisi A dan Divisi B tidak dapat menyeberangi subnet secara langsung. Konfigurasikan jichi sebagai DHCP Relay menuju tengen ([PREFIX IP].4.10), menggunakan eth2 untuk Network 2 dan eth3 untuk Network 3. Buktikan bahwa client dari kedua subnet berhasil memperoleh lease melalui relay.

### Jawaban dan Penjelasan

#### Konfigurasi `jichi` sebagai DHCP Relay

Pada soal ini, node `jichi` dikonfigurasi sebagai DHCP Relay menggunakan `isc-dhcp-relay`. DHCP Relay berfungsi meneruskan permintaan alamat IP dari client Network 2 dan Network 3 menuju DHCP Server `tengen` yang berada di Network 4.

Konfigurasi dilakukan pada file `/etc/default/isc-dhcp-relay` sebagai berikut:

```bash
SERVERS="192.234.4.10"
INTERFACES=""
OPTIONS="-4 -id eth2 -id eth3 -iu eth4"
```

`SERVERS` menentukan IP DHCP Server tujuan, yaitu `tengen` (`192.234.4.10`). Opsi `-id eth2` dan `-id eth3` digunakan untuk menerima permintaan DHCP dari kedua jaringan client, sedangkan `-iu eth4` digunakan sebagai jalur menuju DHCP Server.

Setelah konfigurasi selesai, layanan DHCP Relay dijalankan ulang:

```bash
service isc-dhcp-relay restart
```

### Verifikasi

#### 1. Verifikasi DHCP Relay pada `jichi`

```bash
service isc-dhcp-relay status
ps -eo args | grep '[d]hcrelay'
```

Berdasarkan hasil pengujian, proses `dhcrelay` berjalan menggunakan interface `eth2`, `eth3`, dan `eth4` dengan tujuan DHCP Server `192.234.4.10`. Hal ini menunjukkan bahwa proses DHCP Relay telah aktif sesuai konfigurasi.

<img width="952" height="123" alt="image" src="https://github.com/user-attachments/assets/0c1ee279-b136-46c9-98b9-22db3a671834" />

#### 2. Verifikasi Client `itadori` (Network 2)

```bash
ip -4 -br addr show eth0
```

Hasil pengujian menunjukkan bahwa `itadori` memiliki IP `192.234.2.11/24`, yang termasuk dalam rentang DHCP Network 2, yaitu `192.234.2.10–192.234.2.35`.

<img width="733" height="123" alt="image" src="https://github.com/user-attachments/assets/66f98b4c-6f74-44c8-97bb-092c055c7390" />

#### 3. Verifikasi Client `ino` (Network 3)

```bash
ip -4 -br addr show eth0
```

Hasil pengujian menunjukkan bahwa `ino` memiliki IP `192.234.3.12/24`, yang termasuk dalam rentang DHCP Network 3, yaitu `192.234.3.10–192.234.3.89`.

<img width="714" height="115" alt="image" src="https://github.com/user-attachments/assets/0cf316d8-7c84-4572-8f4b-ec6c1618c3e2" />

Berdasarkan ketiga pengujian tersebut, proses DHCP Relay pada `jichi` telah berjalan dan alamat IP kedua client sesuai dengan rentang yang dikonfigurasi pada DHCP Server `tengen`. Hasil ini mendukung keberhasilan konfigurasi Soal 3, meskipun pemeriksaan lease secara langsung diperlukan untuk membuktikan sumber pemberian IP secara penuh.


## Soal 4

Agar tim Dev dan Support di Divisi A menerima jatah alamat yang berbeda, atur dua pool DHCP pada Network 2. Tetapkan Pool 1 ([PREFIX IP].2.10–[PREFIX IP].2.35) untuk itadori dan fushiguro, serta Pool 2 ([PREFIX IP].2.70–[PREFIX IP].2.95) untuk zenin dan okkotsu. Rentang [PREFIX IP].2.36–[PREFIX IP].2.69 tidak boleh dialokasikan. Karena seluruh client berada pada subnet yang sama, gunakan DHCP class berdasarkan MAC Address atau Client ID untuk memisahkan kedua kelompok.

### Jawaban dan Penjelasan

#### Konfigurasi `tengen`

Pada soal ini, node `tengen` dikonfigurasi untuk membagi alamat IP Network 2 menjadi dua DHCP Pool berdasarkan MAC Address client. Pool 1 digunakan oleh `itadori` dan `fushiguro`, sedangkan Pool 2 digunakan oleh `zenin` dan `okkotsu`.

Pertama, dibuat dua DHCP class untuk mengelompokkan client berdasarkan MAC Address.

```bash
class "divA-pool1" {
  match if substring(hardware, 1, 6) = 02:42:b1:2c:43:00
        or substring(hardware, 1, 6) = 02:42:40:6b:23:00;
}

class "divA-pool2" {
  match if substring(hardware, 1, 6) = 02:42:3b:3a:6b:00
        or substring(hardware, 1, 6) = 02:42:35:6c:75:00;
}
```

Konfigurasi `match if substring(hardware, 1, 6)` digunakan untuk mencocokkan MAC Address client sehingga setiap perangkat dapat dikelompokkan ke dalam DHCP class yang sesuai.

Selanjutnya, dilakukan pembagian pool pada Network 2.

```bash
subnet 192.234.2.0 netmask 255.255.255.0 {
  option routers 192.234.2.1;
  option broadcast-address 192.234.2.255;

  pool {
    allow members of "divA-pool1";
    range 192.234.2.10 192.234.2.35;
  }

  pool {
    allow members of "divA-pool2";
    range 192.234.2.70 192.234.2.95;
  }
}
```

Perintah `allow members of` membatasi penggunaan setiap pool hanya untuk client dengan DHCP class yang sesuai. Dengan demikian, Pool 1 menyediakan IP `192.234.2.10–35` dan Pool 2 menyediakan IP `192.234.2.70–95`. Rentang `192.234.2.36–69` tidak dimasukkan ke dalam pool sehingga tidak dialokasikan.

### Verifikasi

#### 1. Verifikasi DHCP Server `tengen`

```bash
dhcpd -4 -t -cf /etc/dhcp/dhcpd.conf
service isc-dhcp-server status
```

Berdasarkan hasil pengujian, konfigurasi DHCP berhasil divalidasi tanpa error dan layanan menunjukkan status `dhcpd is running`.

<img width="381" height="151" alt="image" src="https://github.com/user-attachments/assets/5c984011-7125-4f6b-8cad-1f2621b02e55" />

#### 2. Verifikasi Pool 1 pada `itadori`

```bash
ip -4 -br addr show eth0
```

Hasil pengujian menunjukkan bahwa `itadori` memiliki IP `192.234.2.13/24`, yang termasuk dalam rentang Pool 1 (`192.234.2.10–35`).

<img width="329" height="76" alt="image" src="https://github.com/user-attachments/assets/1f30123b-9973-4e2c-ae39-d1f2591379a4" />

#### 3. Verifikasi Pool 2 pada `zenin`

```bash
ip -4 -br addr show eth0
```

Setelah melakukan pembaruan DHCP, `zenin` berhasil memperoleh IP `192.234.2.70/24` dari DHCP Server `192.234.4.10` dengan lease time 3600 detik. Alamat tersebut sesuai dengan rentang Pool 2 (`192.234.2.70–95`).

<img width="339" height="47" alt="image" src="https://github.com/user-attachments/assets/e057bc4b-1ac6-4b25-9618-0fe8e8c0d1cf" />

Berdasarkan hasil verifikasi, DHCP Server pada `tengen` berjalan dan kedua client yang diuji telah memiliki alamat IP sesuai kelompok pool masing-masing.

## Soal 5
Setiap tim lapangan memiliki durasi operasi yang berbeda. Pada Network 3, berikan short lease 30 menit (1800 detik) kepada ino dan kusakabe, serta long lease 12 jam (43200 detik) kepada miwa. Gunakan pool short lease [PREFIX IP].3.10–[PREFIX IP].3.89 dan pool long lease [PREFIX IP].3.100–[PREFIX IP].3.199. Sesuaikan default-lease-time dan max-lease-time untuk setiap kelas client. Berikan pula DHCP options berupa DNS [PREFIX IP].1.2 dan [PREFIX IP].1.3, serta domain-search <xxxx>.com.

### Jawaban dan Penjelasan

#### Konfigurasi `tengen`

Pada soal ini, node `tengen` dikonfigurasi untuk membagi alamat IP Network 3 berdasarkan durasi lease time. `ino` dan `kusakabe` mendapatkan short lease selama 1800 detik, sedangkan `miwa` mendapatkan long lease selama 43200 detik.

Pengelompokan client dilakukan menggunakan DHCP class berdasarkan MAC Address.

```bash
class "divB-short" {
  match if substring(hardware, 1, 6) = 02:42:b9:fd:f9:00
        or substring(hardware, 1, 6) = 02:42:4e:89:96:00;
  default-lease-time 1800;
  max-lease-time 1800;
}

class "divB-long" {
  match if substring(hardware, 1, 6) = 02:42:6f:c6:15:00;
  default-lease-time 43200;
  max-lease-time 43200;
}
```

Konfigurasi `default-lease-time` dan `max-lease-time` digunakan untuk menentukan durasi peminjaman IP pada masing-masing kelompok client.

Selanjutnya, dilakukan pembagian dua DHCP pool pada Network 3.

```bash
subnet 192.234.3.0 netmask 255.255.255.0 {
  option routers 192.234.3.1;
  option broadcast-address 192.234.3.255;

  pool {
    allow members of "divB-short";
    range 192.234.3.10 192.234.3.89;
  }

  pool {
    allow members of "divB-long";
    range 192.234.3.100 192.234.3.199;
  }
}
```

Pool pertama menyediakan alamat `192.234.3.10–89` untuk short lease, sedangkan pool kedua menyediakan alamat `192.234.3.100–199` untuk long lease.

Selain itu, ditambahkan DHCP options untuk DNS dan domain-search.

```bash
option domain-name-servers 192.234.1.2, 192.234.1.3;
option domain-name "K46.com";
option domain-search "K46.com";
```

Konfigurasi tersebut mengatur alamat DNS yang diberikan kepada client serta domain pencarian `K46.com`.

### Verifikasi

#### 1. Verifikasi Short Lease pada `ino`

```bash
pkill udhcpc 2>/dev/null
ip addr flush dev eth0
ifdown eth0 2>/dev/null
ifup eth0
ip -4 -br addr show eth0
```

Berdasarkan hasil pengujian, `ino` berhasil memperoleh IP `192.234.3.13/24` dari DHCP Server `192.234.4.10` dengan lease time **1800 detik (30 menit)**. Hasil tersebut sesuai dengan ketentuan short lease.

<img width="497" height="153" alt="image" src="https://github.com/user-attachments/assets/2643cdde-61ee-4ab6-82ed-fad6e23d4b00" />

Selanjutnya, dilakukan pemeriksaan konfigurasi DNS dan domain-search menggunakan perintah:

```bash
cat /etc/resolv.conf
```

Perintah tersebut digunakan untuk memastikan client menerima alamat DNS 192.234.1.2 dan 192.234.1.3, serta domain-search K46.com dari DHCP Server.

<img width="203" height="65" alt="image" src="https://github.com/user-attachments/assets/f48ed7c9-97b2-4a1c-aa2b-b403e3b923bc" />


#### 2. Verifikasi Long Lease pada `miwa`

```bash
pkill udhcpc 2>/dev/null
ip addr flush dev eth0
ifdown eth0 2>/dev/null
ifup eth0
ip -4 -br addr show eth0
```

Berdasarkan hasil pengujian, `miwa` berhasil memperoleh IP `192.234.3.100/24` dari DHCP Server `192.234.4.10` dengan lease time **43200 detik (12 jam)**. Hasil tersebut sesuai dengan ketentuan long lease.

<img width="518" height="152" alt="image" src="https://github.com/user-attachments/assets/56cd593e-9b2a-4ea5-a3bc-198716250b05" />

Berdasarkan kedua pengujian tersebut, pembagian alamat IP dan durasi lease time pada Network 3 telah berjalan sesuai konfigurasi untuk client yang diuji.


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
Para penyihir lapangan bersiaga di Data Center sebagai pekerja backend untuk memproses aplikasi. Pasang Nginx dan PHP-FPM pada **maki** dan **panda** untuk menyajikan web frontend yang menampilkan hostname masing-masing. Pada **nanami**, **todo**, dan **kirara**, siapkan layanan API yang mencatat log request ke database **yaga**. Konfigurasikan virtual host agar worker merespons domain layanan yang ditentukan. Batasi akses langsung dari klien ke worker, web worker hanya menerima trafik melalui jalur proxy web yang ditentukan, sedangkan worker API hanya menerima trafik melalui **geto**. Uji bahwa akses langsung dari klien ditolak, sementara akses melalui reverse proxy tetap berhasil.

### Jawaban dan Penjelasan

Pada soal ini, dilakukan konfigurasi web frontend dan API menggunakan Nginx serta PHP-FPM. Node `maki` dan `panda` berperan sebagai frontend worker, sedangkan `nanami`, `todo`, dan `kirara` berperan sebagai API worker yang mencatat request ke database `yaga`.

#### 1. Konfigurasi Frontend Worker (`maki` dan `panda`)

Kedua node dikonfigurasi untuk menampilkan halaman web yang berisi hostname masing-masing. Akses worker dibatasi agar hanya dapat diterima dari `gojo` sebagai proxy web.

Berikut bagian utama konfigurasi Nginx:

```nginx
server {
    listen 80 default_server;
    server_name jujutsu.k46.com www.jujutsu.k46.com
                frontend.k46.com api.k46.com;

    root /var/www/jarkom14;
    index index.php;

    allow 192.234.1.4;
    deny all;

    location / {
        try_files $uri /index.php$is_args$args;
    }
}
```

Directive `allow` mengizinkan akses dari `gojo` (`192.234.1.4`), sedangkan `deny all` menolak akses langsung dari alamat lainnya. Halaman frontend menggunakan PHP untuk menampilkan hostname server.

#### 2. Konfigurasi API Worker (`nanami`, `todo`, dan `kirara`)

Ketiga API worker dikonfigurasi menggunakan Nginx dan PHP-FPM untuk memproses request API. Setiap request yang berhasil diproses akan dicatat ke tabel `request_logs` pada database `db_shibuya_K46` di `yaga`.

Pembatasan akses dilakukan melalui konfigurasi:

```nginx
allow 192.234.4.2;
deny all;
```

Alamat `192.234.4.2` merupakan IP `geto`. Dengan demikian, API worker hanya menerima request yang berasal dari proxy tersebut.

Respons API berupa JSON yang memuat status request, hostname worker, alamat client, dan ID log.

#### 3. Konfigurasi Jalur Reverse Proxy

Untuk mendukung pengujian Soal 14, digunakan jalur reverse proxy sementara melalui `gojo` dan `geto` pada port `8080`.

Pada `gojo`, request halaman utama diteruskan ke frontend worker `maki` dan `panda`, sedangkan request `/api` diteruskan ke `geto`.

Selanjutnya, `geto` meneruskan request API ke `nanami`, `todo`, dan `kirara`.

Konfigurasi tersebut memungkinkan client mengakses layanan melalui proxy tanpa harus terhubung langsung ke worker.

### Verifikasi

#### 1. Verifikasi Frontend Worker melalui `gojo`

Pengujian dilakukan dari `gojo` untuk memastikan frontend `maki` dan `panda` dapat diakses melalui domain layanan.

```bash
curl -i -H 'Host: jujutsu.k46.com' http://192.234.4.3/
curl -i -H 'Host: jujutsu.k46.com' http://192.234.4.4/
```

Berdasarkan hasil pengujian, kedua frontend worker memberikan respons `HTTP 200 OK` dan menampilkan halaman web dengan hostname masing-masing, yaitu `maki` dan `panda`.

<img width="701" height="315" alt="image" src="https://github.com/user-attachments/assets/dd065f22-b284-4777-8def-eac176ba9499" />

#### 2. Verifikasi API Worker melalui `geto`

Pengujian dilakukan dari `geto` dengan mengirimkan request ke ketiga API worker.

```bash
curl -i http://192.234.4.5/api/uji-nanami
curl -i http://192.234.4.6/api/uji-todo
curl -i http://192.234.4.7/api/uji-kirara
```

Berdasarkan hasil pengujian, ketiga API worker memberikan respons `HTTP 200 OK` dan JSON dengan nilai `"ok":true`. Respons juga menampilkan hostname worker serta `log_id` sebagai tanda bahwa pencatatan request berhasil dilakukan.

<img width="604" height="427" alt="image" src="https://github.com/user-attachments/assets/54a3883b-ee9f-4084-9888-bdf1c26a6a40" />

#### 3. Verifikasi Pencatatan Log pada Database `yaga`

Pemeriksaan dilakukan pada `yaga` untuk memastikan request API tercatat pada tabel `request_logs`.

```bash
mysql -e "SELECT id, client_ip, worker, method, path FROM db_shibuya_K46.request_logs ORDER BY id DESC LIMIT 15;"
```

Pengujian ini bertujuan untuk memastikan bahwa database menyimpan informasi request, termasuk alamat client, nama worker, metode HTTP, dan path yang diakses. Hasil yang diharapkan adalah munculnya record dari worker `nanami`, `todo`, dan `kirara`.

<img width="869" height="296" alt="image" src="https://github.com/user-attachments/assets/96ea6f0a-847c-4d71-9f20-6be227c2bf24" />

#### 4. Verifikasi Pembatasan Akses melalui `itadori`

Pengujian dilakukan dari `itadori` untuk membandingkan akses langsung ke worker dengan akses melalui reverse proxy.

Pengujian akses langsung:

```bash
curl -I http://192.234.4.3/
curl -I http://192.234.4.5/
```

Pengujian akses melalui reverse proxy:

```bash
curl -i --resolve jujutsu.k46.com:8080:192.234.1.4 http://jujutsu.k46.com:8080/

curl -i --resolve jujutsu.k46.com:8080:192.234.1.4 http://jujutsu.k46.com:8080/api/uji-14
```

Berdasarkan hasil pengujian sebelumnya, akses langsung dari client menuju worker menghasilkan `HTTP 403 Forbidden`, sedangkan akses melalui reverse proxy menghasilkan `HTTP 200 OK`.

Hal tersebut membuktikan bahwa pembatasan akses telah diterapkan dan layanan tetap dapat diakses melalui jalur proxy yang ditentukan.

<img width="924" height="499" alt="image" src="https://github.com/user-attachments/assets/af77fbfb-21ee-4946-9a7a-3d9acbb89cc3" />

Berdasarkan pengujian frontend, API, dan pembatasan akses, konfigurasi Soal 14 telah menunjukkan hasil yang sesuai. Pemeriksaan database secara langsung pada `yaga` digunakan sebagai bukti tambahan bahwa log request tersimpan dengan benar.


## Soal 15
Geto bertugas mengendalikan pembagian beban request API di internal Data Center agar server tidak tumbang bersamaan. Konfigurasikan Nginx pada geto sebagai Load Balancer internal dengan upstream api_cluster yang mengarahkan trafik ke nanami dan todo. Terapkan algoritma Weighted Round Robin dengan bobot 3:1, di mana nanami menerima porsi beban tiga kali lebih banyak daripada todo. Buktikan distribusi beban ini dengan melakukan loop request berulang kali ke geto dari jaringan lokal Data Center dan periksa rasio responnya.

### Jawaban dan Penjelasan

#### Konfigurasi `geto`

Pada soal ini, node `geto` dikonfigurasi sebagai Load Balancer menggunakan Nginx untuk mendistribusikan request API ke `nanami` dan `todo` dengan algoritma Weighted Round Robin.

Konfigurasi dilakukan pada file `/etc/nginx/conf.d/soal15.conf` dengan membuat upstream `api_cluster`.

```nginx
upstream api_cluster {
    zone api_cluster 64k;
    server 192.234.4.5:80 weight=3 max_fails=2 fail_timeout=5s;
    server 192.234.4.6:80 weight=1 max_fails=2 fail_timeout=5s;
    server 192.234.4.7:80 backup;
}
```

Konfigurasi `weight=3` pada `nanami` dan `weight=1` pada `todo` digunakan untuk membagi request dengan rasio 3:1. Artinya, dalam kondisi kedua worker aktif, sekitar 75% request akan diteruskan ke `nanami` dan 25% ke `todo`.

Directive `zone` digunakan untuk menyimpan status upstream yang dapat dibagikan antarproses Nginx. Pada konfigurasi yang telah berjalan juga terdapat `max_fails`, `fail_timeout`, dan `kirara` sebagai backup, yang berkaitan dengan pengaturan failover pada Soal 18.

### Verifikasi

#### 1. Verifikasi Konfigurasi Load Balancer pada `geto`

Pengujian dilakukan untuk memastikan konfigurasi Nginx valid dan pembagian bobot pada upstream `api_cluster` sudah sesuai.

```bash
nginx -t && grep -A4 'upstream api_cluster' /etc/nginx/conf.d/soal15.conf
```

Berdasarkan hasil pengujian, konfigurasi Nginx berhasil divalidasi dengan pesan `syntax is ok` dan `test is successful`. Konfigurasi upstream juga menunjukkan bahwa `nanami` memiliki bobot 3, sedangkan `todo` memiliki bobot 1.

<img width="601" height="125" alt="image" src="https://github.com/user-attachments/assets/b679fb42-90d8-4c62-98eb-0043ae636b19" />

#### 2. Verifikasi Distribusi Request pada `maki`

Pengujian dilakukan dari node `maki` yang berada di jaringan Data Center dengan mengirimkan 40 request secara berulang ke Load Balancer `geto`.

```bash
for i in $(seq 1 40); do
  curl -s http://192.234.4.2/api/uji-$i | grep -o '"worker":"[^"]*"'
done | sort | uniq -c
```

Berdasarkan hasil pengujian, diperoleh distribusi request sebagai berikut:

<img width="470" height="103" alt="image" src="https://github.com/user-attachments/assets/0202dcb1-d750-435d-979f-89883f040546" />


Dari total 40 request, `nanami` menerima 30 request (75%), sedangkan `todo` menerima 10 request (25%). Hasil tersebut menunjukkan bahwa distribusi beban telah sesuai dengan rasio Weighted Round Robin sebesar 3:1.
Berdasarkan hasil pengujian, Load Balancer pada `geto` berhasil mendistribusikan request API ke `nanami` dan `todo` sesuai bobot yang ditentukan. Dengan demikian, penerapan algoritma Weighted Round Robin 3:1 telah berjalan sesuai ketentuan soal.


## Soal 16

### Soal

Gojo berdiri di perbatasan DMZ sebagai gerbang publik tunggal bagi seluruh client dari luar maupun dalam. Konfigurasikan Nginx pada gojo untuk melayani domain jujutsu.<xxxx>.com dan www.jujutsu.<xxxx>.com menggunakan metode Path-Based Routing. Atur agar request root (/) diteruskan secara Round Robin ke worker frontend (maki dan panda), sedangkan request ke path /api diteruskan langsung ke geto. Uji dari client Divisi A atau B bahwa akses ke web utama dibalas oleh Maki/Panda, sedangkan akses ke /api diteruskan dan dijawab oleh Nanami/Todo.

### Jawaban dan Penjelasan

#### Konfigurasi `gojo`

Pada soal ini, node `gojo` dikonfigurasi sebagai reverse proxy menggunakan Nginx dengan metode Path-Based Routing. Request menuju halaman utama (`/`) diteruskan secara Round Robin ke `maki` dan `panda`, sedangkan request menuju `/api` diteruskan ke `geto` untuk diproses oleh API worker.

Konfigurasi dilakukan pada file `/etc/nginx/conf.d/soal16.conf`.

Pertama, dibuat upstream `frontend_cluster` untuk mendistribusikan request ke kedua frontend worker.

```nginx
upstream frontend_cluster {
    zone frontend_cluster 64k;
    server 192.234.4.3:80;
    server 192.234.4.4:80;
}
```

Kedua server memiliki bobot yang sama sehingga Nginx menggunakan algoritma Round Robin untuk membagi request secara bergantian.

Selanjutnya, dilakukan konfigurasi virtual host dan Path-Based Routing.

```nginx
server {
    listen 80 default_server;
    server_name jujutsu.k46.com www.jujutsu.k46.com;

    location = /api {
        proxy_pass http://192.234.4.2:80;
    }

    location ^~ /api/ {
        proxy_pass http://192.234.4.2:80;
    }

    location / {
        proxy_pass http://frontend_cluster;
    }
}
```

Konfigurasi `location /` digunakan untuk meneruskan request halaman web ke frontend worker. Sementara itu, `location = /api` dan `location ^~ /api/` digunakan untuk meneruskan request API ke `geto` (`192.234.4.2`) tanpa mengubah path request.

### Verifikasi

#### 1. Verifikasi Konfigurasi pada `gojo`

Pengujian dilakukan untuk memastikan konfigurasi Nginx valid dan Path-Based Routing telah diterapkan.

```bash
nginx -t && grep -E 'server_name|upstream frontend_cluster|server 192.234.4.[34]:80|location|proxy_pass' /etc/nginx/conf.d/soal16.conf
```

Berdasarkan hasil pengujian, konfigurasi Nginx berhasil divalidasi dengan pesan `syntax is ok` dan `test is successful`. Konfigurasi juga menunjukkan upstream `frontend_cluster` yang berisi `maki` dan `panda`, serta pemisahan routing berdasarkan path.

<img width="933" height="181" alt="image" src="https://github.com/user-attachments/assets/54d683f8-e131-4f96-b893-fd05ef53f351" />

#### 2. Verifikasi Frontend melalui `itadori`

Pengujian dilakukan dari `itadori` dengan mengirimkan request ke halaman utama melalui kedua domain layanan.

```bash
for domain in jujutsu.k46.com www.jujutsu.k46.com; do
  for i in 1 2 3 4; do
    curl -sSi --resolve "$domain:80:192.234.1.4" "http://$domain/" | grep -Ei '^HTTP/|^X-Gojo-Route:|Frontend worker:'
  done
done
```

Berdasarkan hasil pengujian, seluruh request menghasilkan `HTTP 200 OK` dengan header `X-Gojo-Route: frontend`. Dari 8 request yang dikirimkan, `maki` dan `panda` masing-masing merespons 4 kali. Hasil tersebut menunjukkan bahwa distribusi Round Robin berjalan dengan rasio 1:1.

<img width="909" height="419" alt="image" src="https://github.com/user-attachments/assets/cf588f1a-f4ae-4907-8361-93b33f6e1bc5" />

#### 3. Verifikasi API melalui `itadori`

Pengujian dilakukan untuk memastikan request `/api` diteruskan oleh `gojo` menuju `geto` dan diproses oleh API worker.

```bash
curl -sSi --resolve jujutsu.k46.com:80:192.234.1.4 http://jujutsu.k46.com/api/uji-soal16
```

Pengujian juga dilakukan pada domain `www.jujutsu.k46.com`.

```bash
curl -sSi --resolve www.jujutsu.k46.com:80:192.234.1.4 http://www.jujutsu.k46.com/api/uji-soal16
```

Berdasarkan hasil pengujian yang berhasil, diperoleh respons `HTTP 200 OK` dengan header:

```text
X-Gojo-Route: api
X-Gojo-Upstream: 192.234.4.2:80
```

Respons JSON juga menampilkan `"ok":true` dan `"worker":"nanami"`. Hal ini membuktikan bahwa request API berhasil diteruskan dari `gojo` melalui `geto` dan diproses oleh API worker.

<img width="820" height="397" alt="image" src="https://github.com/user-attachments/assets/489a5d25-9562-428b-96da-6d99b1c2fec5" />

Berdasarkan hasil pengujian, konfigurasi Path-Based Routing pada `gojo` telah berjalan sesuai ketentuan. Request halaman utama berhasil didistribusikan ke `maki` dan `panda` menggunakan Round Robin, sedangkan request `/api` berhasil diteruskan melalui `geto` menuju API worker.


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
