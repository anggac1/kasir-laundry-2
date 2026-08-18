# Kasir Laundry

Aplikasi kasir laundry untuk Android. **Sepenuhnya offline**, tanpa login, tanpa server, tanpa akun.

Dibuat sebagai pengganti Lakasir POS yang mewajibkan login dan menyimpan semua data di server.

---

## Perbandingan dengan Lakasir POS

| | Lakasir POS | Aplikasi ini |
|---|---|---|
| Login | Wajib | **Tidak ada** |
| Database | Server (online) | **SQLite di HP** |
| Butuh internet | Ya, selalu | **Tidak sama sekali** |
| Izin INTERNET | Ada | **Tidak ada** |
| Data pelanggan | Terkirim ke server | **Tidak pernah keluar dari HP** |
| Template struk | Tidak bisa diubah | **Bisa diedit di dalam aplikasi** |

Aplikasi ini bahkan **tidak meminta izin `INTERNET`** di AndroidManifest. Artinya, secara teknis sistem Android sendiri yang mencegahnya mengirim data ke mana pun — bukan sekadar janji, tapi dibatasi di level sistem operasi.

---

## Dua Cara Memakai Proyek Ini

**Cuma butuh APK jadi?** Ikuti bagian di bawah ini — GitHub yang membangunkan, laptop Anda tidak perlu diinstal apa pun.

**Mau mengubah kode sendiri?** Baca [SETUP_LOKAL.md](SETUP_LOKAL.md) — daftar lengkap yang harus diunduh, ekstensi VS Code, dan cara menjalankan langsung di HP dengan hot reload.

---

## Cara Mendapatkan File APK

Anda tidak perlu menginstal apa pun di laptop. GitHub yang akan membangunkan APK-nya secara gratis.

### 1. Buat repositori baru

Buka [github.com/new](https://github.com/new). Isi nama repo bebas, misalnya `kasir-laundry`. Boleh dipilih **Private** — GitHub Actions tetap gratis untuk repo privat. Jangan centang opsi "Add a README file". Klik **Create repository**.

### 2. Unggah semua file

Ekstrak dulu ZIP-nya, lalu **klik dua kali `push_ke_github.bat`** di dalam folder hasil ekstrak. Tempel URL repo Anda saat diminta, dan selesai.

Cara ini dipakai karena **unggah lewat halaman web GitHub sering meratakan struktur folder** — semua file `.dart` mendarat di root, `lib/` hilang, `.github/workflows/` hilang, dan build tidak akan pernah jalan. Script ini memakai Git, yang selalu mempertahankan struktur apa adanya.

Syaratnya cuma [Git for Windows](https://git-scm.com/download/win) sudah terpasang.

<details>
<summary>Kalau tetap ingin lewat web</summary>

Buka halaman repo → **uploading an existing file**. Masuk ke folder hasil ekstrak, tekan `Ctrl+A` untuk memilih **semua isinya sekaligus** — termasuk folder `lib`, `.github`, dan `android_overrides` — lalu seret semuanya dalam satu tarikan.

Jangan pernah membuka `lib` lalu menyeret file `.dart` satu per satu. Itu penyebab struktur menjadi rata.

Setelah unggah, periksa halaman repo. Yang benar terlihat seperti ini:

```
.github/          lib/          android_overrides/
pubspec.yaml      README.md     setup_lokal.bat
```

Kalau yang muncul justru `beranda.dart`, `db.dart`, dan kawan-kawannya berjajar di root, berarti gagal — hapus semuanya dan ulangi.

Folder `.github` diawali titik dan sering disembunyikan Windows. Aktifkan **Hidden items** di tab View pada File Explorer.

</details>

### 3. Tunggu build selesai

Buka tab **Actions** di repo Anda. Akan ada proses bernama "Build APK" yang berjalan otomatis dengan ikon lingkaran kuning berputar.

Prosesnya sekitar 5–10 menit untuk build pertama. Kalau ikonnya berubah jadi centang hijau, build berhasil.

### 4. Unduh APK

Klik proses build yang sudah selesai. Gulir ke bawah sampai bagian **Artifacts**, lalu klik **kasir-laundry-apk** untuk mengunduh.

Hasil unduhan berupa file ZIP. Ekstrak, dan di dalamnya ada `kasir-laundry.apk`.

### 5. Pasang di HP

Kirim APK itu ke HP (lewat WhatsApp ke diri sendiri, kabel USB, atau Google Drive), lalu buka filenya.

Android akan menanyakan izin "Instal aplikasi tidak dikenal" karena tidak berasal dari Play Store. Izinkan untuk aplikasi tempat Anda membuka file tersebut, lalu lanjutkan pemasangan.

---

## Kalau Build Gagal

Buka tab Actions, klik proses yang gagal (ikon silang merah), dan lihat langkah mana yang berwarna merah. Beberapa masalah yang mungkin muncul:

**Gagal di langkah "Ambil dependensi"** — biasanya karena versi paket di `pubspec.yaml` sudah tidak tersedia. Buka `pubspec.yaml`, hapus tanda `^` dan nomor versinya sehingga jadi misalnya `sqflite: any`, lalu commit ulang.

**Gagal di langkah "Build APK release"** dengan pesan soal `namespace` — berarti tambalan otomatis belum cukup. Salin pesan errornya dan kirimkan ke saya.

**`Cannot run Project.afterEvaluate(Closure) when the project is already evaluated`** — tambalan namespace masuk ke bagian bawah `android/build.gradle`, padahal harus di bagian atas. Sudah diperbaiki sejak versi ini; kalau masih muncul, pastikan `android_overrides/namespace_patch.gradle` dan `.github/workflows/build.yml` benar-benar versi terbaru.

**Tidak ada proses apa pun di tab Actions** — folder `.github` tidak ikut terunggah. Ulangi langkah 2 dan pastikan folder tersembunyi ikut terbawa.

---

## Cara Pakai Aplikasi

### Pertama kali dibuka

1. Buka menu titik tiga di kanan atas → **Pengaturan**
2. Isi nama laundry, alamat, dan nomor telepon
3. Masuk ke **Pilih printer**, lalu pilih printer thermal Anda

> Printer harus **sudah dipasangkan lebih dulu** lewat Pengaturan Bluetooth bawaan HP. Aplikasi ini hanya menampilkan perangkat yang sudah terpasang, tidak melakukan pemindaian sendiri.

4. Tekan **Tes Cetak** untuk memastikan hasilnya rapi
5. Buka menu → **Daftar Layanan**, sesuaikan daftar dan harganya

Aplikasi sudah berisi 10 contoh layanan (cuci kering, cuci setrika, bed cover, sepatu, dan lain-lain). Silakan ubah atau hapus sesuai laundry Anda.

### Membuat nota

Tekan tombol **Nota Baru**, isi nama pelanggan, tambahkan item layanan, lalu simpan. Untuk layanan kiloan, berat boleh desimal seperti `3.5`.

Harga tiap item masih bisa diubah khusus untuk nota itu saja, tanpa mengubah daftar harga utama.

### Cetak beberapa salinan

**Pengaturan → Salinan Struk.** Pilih 1–3 lembar dan atur judul tiap lembar, bawaannya `PELANGGAN,ARSIP TOKO`. Placeholder `{salinan}` berisi judul lembar itu, jadi satu template menghasilkan lembar yang berbeda-beda. Semua lembar dikirim sebagai satu paket, printer hanya disambungi sekali.

### Field tambahan buatan sendiri

**Pengaturan → Field Tambahan.** Ketik nama field, misalnya "Parfum", dan placeholder `{parfum}` dibuat otomatis. Kolom isiannya muncul di layar Nota Baru, dan placeholder-nya bisa dipasang di mana saja pada template struk. Nama dua kata jadi garis bawah: "Jenis Cucian" → `{jenis_cucian}`.

Menghapus field tidak merusak nota lama — isian yang sudah tersimpan tetap ada di dalamnya.

### Ekspor laporan

**Pengaturan → Data → Ekspor laporan.** Pilih rentang waktu, lalu ekspor sebagai PDF (laporan A4 berkop) atau Excel (dua lembar: ringkasan per nota, dan rincian tiap item). Berkasnya lewat menu berbagi bawaan HP, jadi bisa disimpan ke mana saja atau dikirim lewat WhatsApp.

### Layar debug

**Pengaturan → Data → Debug.** Tiga tab: **Uji Hitung** untuk menelusuri rumus dan mengaudit seluruh nota, **Kode Logika** berisi salinan kode inti dengan catatan jebakannya, dan **Struk Mentah** yang menampilkan hasil render template plus hex dump byte ESC/POS.

Perlu diingat tab Kode Logika adalah salinan teks, bukan kode yang benar-benar berjalan. Kalau Anda mengubah logika, perbarui juga `lib/debug/kode_sumber.dart`.

### Printer RPP02N

**Pengaturan → Printer → Pakai profil RPP02N** menyetel semuanya sekaligus: 58mm, 32 karakter, Font A, tanpa pisau potong. RPP02N memakai 384 dot per baris dan ESC/POS standar, jadi cocok dengan setelan bawaan.

Jangan menyalakan "Potong kertas otomatis" — RPP02N tidak punya pisau, dan perintah potong bisa membuatnya menggantung. Ada juga opsi Font B kalau ingin muat 42 karakter per baris; ingat ubah Lebar kertas jadi 42 kalau opsi itu dinyalakan.

### Status pesanan dan pembayaran

Keduanya dilacak terpisah, karena pelanggan laundry sering bayar di belakang:

- **Status pesanan:** Diterima → Diproses → Selesai → Diambil
- **Status bayar:** Belum Bayar / Lunas

Status bayar punya tiga pilihan: **Belum**, **Lunas**, dan **Sembunyi**. Pilih Sembunyi kalau baris pembayaran tidak perlu tercetak — Anda tidak dipaksa memilih salah satu yang keliru.

Kalau pelanggan membayar saat mengambil cucian, cukup buka notanya dan ketuk **Lunas**. Hanya baris itu yang berubah, tidak perlu cetak ulang, dan waktu pelunasan tercatat otomatis memakai jam HP.

Ada juga kolom **Uang diterima** yang opsional. Kembalian dihitung otomatis. Kalau dikosongkan, baris uang dan kembalian tidak ikut tercetak sama sekali — ini memakai tag `[?kunci]` pada template, yang melewati baris bila nilainya kosong.

Di beranda ada filter cepat untuk melihat nota yang **Belum Lunas** atau yang **belum diambil**.

---

## Mengatur Teks Struk

Ini bagian yang paling bisa Anda atur sendiri. Buka menu → **Template Struk**.

Isi struk bawaan sengaja diisi teks *lorem ipsum* supaya panjang barisnya terlihat. Silakan ganti seluruhnya dengan kata-kata Anda sendiri.

### Teks flat dan teks berubah

**Teks flat** adalah semua yang Anda ketik biasa. Dicetak persis sama di setiap struk — cocok untuk nama laundry, alamat, syarat & ketentuan, dan ucapan terima kasih.

**Teks berubah** ditulis dalam kurung kurawal dan diganti otomatis sesuai isi nota. Tekan tombol placeholder di bagian bawah layar untuk menyisipkannya, tidak perlu mengetik manual.

| Placeholder | Berubah menjadi |
|---|---|
| `{nama_toko}` | Nama laundry dari Pengaturan |
| `{alamat_toko}` | Alamat laundry |
| `{telepon_toko}` | Telepon / WA |
| `{no_nota}` | Nomor nota, contoh LDY-260816-001 |
| `{tanggal}` `{jam}` `{hari}` | Waktu nota dibuat, dari jam HP |
| `{nama_pelanggan}` | Nama pelanggan |
| `{estimasi}` | Perkiraan tanggal selesai |
| `{status_pesanan}` | Diterima / Diproses / Selesai / Diambil |
| `{status_bayar}` | LUNAS atau BELUM BAYAR |
| `{total}` | Total harga |
| `{jumlah_item}` | Banyaknya baris item |
| `{catatan}` | Catatan nota |
| `{daftar_item}` | Seluruh daftar item |

Khusus di tab **Baris Item**, tersedia `{no}`, `{nama_item}`, `{qty}`, `{satuan}`, `{harga}`, dan `{subtotal}`.

### Tag pengatur tampilan

Ditulis di awal baris, boleh digabung seperti `[B][C]` atau `[BC]`:

| Tag | Fungsi |
|---|---|
| `[C]` | Rata tengah |
| `[R]` | Rata kanan |
| `[L]` | Rata kiri (bawaan) |
| `[B]` | Huruf tebal |
| `[H]` | Huruf besar dobel |

Dua tag khusus:

- `[>]` mendorong sisa teks ke pinggir kanan. Contoh `TOTAL[>]{total}` menghasilkan `TOTAL` di kiri dan nominalnya menempel di kanan.
- `---` (tiga strip atau lebih) membuat garis pemisah selebar kertas. Bisa juga `===` atau `***`.

Teks yang terlalu panjang otomatis dipotong ke baris berikutnya agar muat di lebar kertas.

### Melihat hasilnya

Tab **Pratinjau** menampilkan contoh struk memakai data nota palsu, langsung dari teks yang sedang Anda ketik. Jangan lupa tekan ikon simpan di kanan atas.

Kalau hasil editan berantakan, ikon **↺** di kanan atas mengembalikan template ke bawaan.

---

## Struktur Kode

```
lib/
├── main.dart                    Titik masuk aplikasi
├── models/models.dart           Layanan, Nota, ItemNota, status
├── db/db.dart                   SQLite lokal, semua query
├── store/settings.dart          Pengaturan + template bawaan
├── print/
│   ├── receipt.dart             Mesin template: placeholder & tag
│   ├── escpos.dart              Penyusun byte ESC/POS
│   └── printer_service.dart     Koneksi Bluetooth
├── screens/
│   ├── beranda.dart             Daftar nota, ringkasan, filter
│   ├── nota_baru.dart           Buat & ubah nota
│   ├── nota_detail.dart         Detail, status, cetak
│   ├── layanan.dart             Kelola layanan & harga
│   ├── template_editor.dart     Editor struk
│   ├── pengaturan.dart          Pengaturan umum
│   └── printer_setup.dart       Pilih printer & tes cetak
└── utils/fmt.dart               Format rupiah & tanggal
```

Folder `android/` tidak ada di repo karena dibuat otomatis oleh GitHub Actions. Yang disimpan hanya `android_overrides/AndroidManifest.xml`, berisi daftar izin dan nama aplikasi.

---

## Catatan Penting

**Tidak ada cadangan otomatis.** Semua data hanya ada di HP itu. Kalau HP hilang, rusak, atau aplikasinya dicopot, seluruh riwayat nota ikut hilang. Ini konsekuensi langsung dari database yang sepenuhnya lokal. Kalau nanti Anda butuh fitur ekspor ke file atau cadangan otomatis, tinggal bilang.

**APK ditandatangani kunci debug.** Karena tidak ada keystore yang disiapkan, Flutter memakai kunci debug bawaan. Aplikasinya tetap bisa dipasang dan dipakai normal. Yang perlu diingat: kalau nanti Anda membuat keystore sendiri, aplikasi harus dicopot dulu sebelum memasang versi baru, karena Android menolak pembaruan dengan tanda tangan berbeda.

**Printer Bluetooth Classic.** Kode ini memakai jalur Bluetooth Classic (SPP), yang dipakai hampir semua printer thermal murah. Printer harus dipasangkan lewat pengaturan HP terlebih dahulu.

**Belum diuji di perangkat nyata.** Kode ini ditulis tanpa kesempatan menjalankannya di HP. Kalau ada layar yang error atau hasil cetak tidak rapi, kirimkan pesan errornya dan akan saya perbaiki.
