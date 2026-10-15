# Per-question scripts - Modul 3 K-46

Format mengikuti contoh `perquest-scripts` Modul 2: satu `soal_N.sh` per nomor, bagian `# ==== NODE ... ====`, konfigurasi, lalu verifikasi. Paket ini berisi **nomor 1-5** dengan prefix **192.229**.

File dapat dibaca atau disalin per bagian node. Jika dijalankan sebagai file, nama node terdeteksi dari hostname sehingga hanya bagian node terkait yang diterapkan. Simpan file dalam direktori `/root` pada node yang sesuai.

| File | Node | Isi |
| --- | --- | --- |
| `soal_1.sh` | jichi dan 12 host infrastruktur | WAN NAT, empat gateway /24, IPv4 forwarding, MASQUERADE, IP statis, startup dan verifikasi. |
| `soal_2.sh` | tengen | Instalasi ISC DHCP Server, subnet lokal Network 4 tanpa pool, scope Network 2/3, startup server, penyimpanan lease. |
| `soal_3.sh` | jichi | Relay eth2/eth3 downstream, eth4 upstream, menuju 192.229.4.10. |
| `soal_4.sh` | tengen | Class MAC dan dua pool Network 2; .2.36-.2.69 tidak dialokasikan. |
| `soal_5.sh` | tengen serta tujuh client | Pool/class Network 3, short/long lease, DNS/domain-search, serta DHCP client dan renew. |

## Cara menjalankan

Misalnya folder paket disalin ke `/root/perquest-scripts`:

1. Pada **jichi** dan masing-masing **host infrastruktur**, jalankan:

   ```sh
   sh /root/perquest-scripts/soal_1.sh
   ```

2. Pada **tengen**:

   ```sh
   sh /root/perquest-scripts/soal_2.sh
   ```

3. Pada **jichi**:

   ```sh
   sh /root/perquest-scripts/soal_3.sh
   ```

4. Pada **tengen**:

   ```sh
   sh /root/perquest-scripts/soal_4.sh
   sh /root/perquest-scripts/soal_5.sh
   ```

5. Pada **Itadori, Fushiguro, Zenin, Okkotsu, ino, Kusakabe, dan Miwa**, jalankan file nomor 5 pada masing-masing console:

   ```sh
   sh /root/perquest-scripts/soal_5.sh
   ```

Pada pemasangan baru, soal 2 menyiapkan scope tanpa pool; pool dialokasikan oleh soal 4 dan 5. Bukti lease untuk soal 3 diperiksa setelah seluruh kebijakan pool dan client siap. Pada project yang sudah kita konfigurasi, nomor 2 dapat mengimpor class/pool lama agar konfigurasi yang sudah ada tetap terbawa.

## Verifikasi

Pada tengen:

```sh
sh /root/soal_2.sh --verify
dhcpd -4 -t -cf /etc/dhcp/dhcpd.conf
service isc-dhcp-server status
cat /var/lib/dhcp/dhcpd.leases
```

Pada jichi:

```sh
sh /root/no3-jichi.sh --verify
```

Pada client, misalnya Miwa:

```sh
sh /root/no2-client.sh miwa --verify
sh /root/no2-client.sh miwa --renew
```

Pool dan durasi yang harus diterima:

| Client | Pool | Lease |
| --- | --- | --- |
| Itadori/Fushiguro | 192.229.2.10-35 | 3.600 detik |
| Zenin/Okkotsu | 192.229.2.70-95 | 3.600 detik |
| ino/Kusakabe | 192.229.3.10-89 | 1.800 detik |
| Miwa | 192.229.3.100-199 | 43.200 detik |

Seluruh client menerima mask /24, gateway subnet masing-masing, DNS 192.229.1.2 dan 192.229.1.3, serta domain-search K46.com. Paket ini khusus prefix dan MAC kelompok K-46. Kugisaki menjadi bagian nomor 6.

## Struktur konfigurasi per soal

Server menyimpan fragment pada `/root/no2-5/perquest.d/`:

- `10-soal4-classes.conf` dan `40-network2-pools.conf`: milik soal 4.
- `20-soal5-classes.conf` dan `50-network3-pools.conf`: milik soal 5.
- `30-extra-hosts.conf`: ruang konfigurasi host tambahan untuk nomor berikutnya.

Soal 2 membuat fragment hanya jika belum ada; menjalankannya ulang mempertahankan isi soal 4/5. Soal 4 dan 5 hanya mengganti fragment miliknya, lalu meminta soal 2 memvalidasi dan membangun ulang konfigurasi gabungan. Jika validasi/restart gagal, fragment sebelumnya dipulihkan. Database lease dalam `/root/no2-5/dhcpd.leases` tidak dikosongkan.

Startup server yang lama diganti saat soal 2 diterapkan, agar restart menggunakan konfigurasi fragment. Hook nomor 1 dan relay dipertahankan. File asli konfigurasi sebelum migrasi disalin ke `/root/no2-5/perquest-backup-before/`.

## Pemeriksaan paket ini

`VALIDASI.json` mencatat:

- Sintaks kelima script dan dua script yang ditanam pada soal 5 lolos `sh -n`.
- Konfigurasi DHCP pada tahap soal 2, soal 4, dan soal 5 lolos `dhcpd -t`.
- Migrasi dari konfigurasi monolitik sebelumnya mempertahankan semua class, pool, DNS, dan lease policy.
- Menjalankan migrasi ulang mempertahankan isi fragment.
- Implementasi client soal 5 identik dengan script yang telah lolos uji lease, renew, dan restart.

Penyusunan format ini tidak menjalankan ulang konfigurasi pada project live. Pengujian format memakai file sementara dan pemeriksaan konfigurasi; layanan aktif dan konfigurasi live sebelumnya tetap dipertahankan. Hasil uji konektivitas/lease sebelumnya tersedia pada paket nomor 1 dan nomor 2-5 yang telah diberikan.
