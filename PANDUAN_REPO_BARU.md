# Pindah ke Repo Baru

Panduan lengkap memutus repo lama `anggac1/kasir` dan mulai bersih di `anggac1/kasir-laundry-2`.

Semua dikerjakan di folder proyek:

```
D:\Kuliah_ML\Claude\kasir-laundry-source
```

---

## Ringkasan

| Langkah | Di mana | Perkiraan waktu |
|---|---|---|
| 1. Buat repo kosong | Browser | 1 menit |
| 2. Jalankan `repo_baru.bat` | File Explorer | 2 menit |
| 3. Tunggu build | Browser, tab Actions | 5–10 menit |
| 4. Unduh dan pasang APK | Browser lalu HP | 3 menit |
| 5. Uji printer | HP | 2 menit |

Anda **tidak perlu mengetik satu perintah Git pun**. Semua diurus script.

---

## Langkah 1 — Buat Repo Kosong di GitHub

Buka [github.com/new](https://github.com/new)

| Kolom | Isi |
|---|---|
| Repository name | `kasir-laundry-2` |
| Visibility | Public atau Private, keduanya bebas |
| Add a README file | **Jangan dicentang** |
| Add .gitignore | **Jangan dipilih** |
| Choose a license | **Jangan dipilih** |

Klik **Create repository**.

> Ketiga opsi tambahan itu harus dikosongkan. Kalau dicentang, GitHub membuat commit awal sendiri, dan itu berbenturan dengan unggahan kita nanti.

Setelah repo jadi, muncul halaman berisi petunjuk. **Abaikan semuanya**, kita tidak memakai cara itu. Yang Anda butuhkan hanya URL-nya:

```
https://github.com/anggac1/kasir-laundry-2.git
```

Salin URL itu, atau cukup ingat namanya.

---

## Langkah 2 — Jalankan repo_baru.bat

Buka folder `D:\Kuliah_ML\Claude\kasir-laundry-source` di File Explorer.

**Klik dua kali** berkas:

```
repo_baru.bat
```

Jendela hitam terbuka. Yang terjadi di dalamnya:

**Pertama**, script memasang `build.yml` versi terbaru secara otomatis. Ini menggantikan pekerjaan edit manual yang selama ini merepotkan Anda. Isinya diambil dari `ci\build.yml.txt`.

**Kedua**, script meminta URL repo. Tempel URL dari langkah 1, lalu Enter.

> Untuk menempel di jendela hitam, **klik kanan** di dalamnya. `Ctrl+V` sering tidak berfungsi di sana.

**Ketiga**, muncul konfirmasi. Ketik `Y` lalu Enter.

**Keempat**, script memutus repo lama dengan menghapus folder `.git`, lalu memulai riwayat baru dan mengunggahnya ke repo tujuan.

> **Apa yang dihapus:** hanya riwayat Git, yaitu catatan siapa mengubah apa. **Kode Anda tidak ada yang hilang** — seluruh isi `lib/`, `pubspec.yaml`, dan berkas lainnya tetap utuh di folder dan ikut terunggah ke repo baru.

**Kelima**, kalau ini pertama kalinya Git dipakai di laptop ini, muncul jendela login GitHub. Masuk dengan akun Anda. Setelah itu tidak diminta lagi.

Kalau berhasil, muncul tulisan:

```
============================================
  Berhasil.

  Buka repo Anda di GitHub, masuk tab Actions.
============================================
```

---

## Langkah 3 — Periksa Hasil Unggahan

Buka `https://github.com/anggac1/kasir-laundry-2` di browser.

Halaman depannya harus menampilkan **folder**, bukan tumpukan berkas `.dart`:

```
.github/     android_overrides/     ci/     lib/
README.md    SETUP_LOKAL.md         pubspec.yaml
```

Kalau yang muncul justru `beranda.dart`, `db.dart`, dan kawan-kawannya berjajar di halaman depan, berarti ada yang salah — beri tahu saya sebelum lanjut.

Sekarang buka tab **Actions**. Akan ada proses bernama **Build APK** dengan lingkaran kuning berputar. Klik untuk melihat detailnya.

Tunggu 5–10 menit untuk build pertama. Kalau ikonnya berubah jadi **centang hijau**, berhasil.

---

## Langkah 4 — Unduh dan Pasang APK

Di halaman build yang sudah selesai, gulir ke bawah sampai bagian **Artifacts**. Klik **kasir-laundry-apk** untuk mengunduh.

Hasil unduhan berupa ZIP. Ekstrak, di dalamnya ada `kasir-laundry.apk`.

Kirim ke HP lewat kabel USB, WhatsApp ke diri sendiri, atau Google Drive. Buka berkasnya di HP.

> **Copot dulu aplikasi lama** sebelum memasang yang baru. Versi lama dan baru ditandatangani kunci debug yang sama sehingga biasanya bisa langsung menimpa, tapi mencopot lebih dulu menghilangkan seluruh kemungkinan bentrok. Ingat, data nota Anda akan ikut terhapus — kalau masih ada nota penting, ekspor dulu lewat Pengaturan.

---

## Langkah 5 — Uji Printer

Buka aplikasi → menu titik tiga di kanan atas → **Pengaturan** → **Pilih printer**.

### Yang harus Anda lihat

Sebuah **kotak abu-abu berjudul Status** berisi tiga baris:

```
Status
  ✓ Izin Bluetooth: Diberikan
  ✓ Bluetooth HP: Menyala
  ✓ Perangkat terpasang: 1
```

**Kalau kotak ini muncul, APK-nya sudah versi benar.** Kalau yang muncul justru lingkaran berputar terus tanpa kotak apa pun, berarti APK lama masih terpasang — copot dan pasang ulang.

Pilih **RPP02N** dari daftar perangkat, lalu tekan **Tes Cetak**.

### Kalau tes cetak gagal

Akan muncul dialog **Cetak Gagal** berisi rincian langkah seperti ini:

```
Printer tersimpan: RPP02N (66:22:9E:...)
Ukuran data: 412 byte
Izin Bluetooth: diberikan
Bluetooth HP: menyala
Sambung ke printer: gagal (percobaan 1)
Sambung ke printer: berhasil (percobaan 2)
Kirim data: gagal di byte ke-256 dari 412
```

**Foto dialog itu dan kirim ke saya.** Karena RawBT sudah membuktikan printernya sehat, penyebabnya pasti ada di salah satu baris tersebut.

---

## Untuk Perubahan Berikutnya

Setelah repo baru berdiri, Anda **tidak perlu menjalankan `repo_baru.bat` lagi** — script itu menghapus riwayat setiap kali dijalankan.

Untuk mengirim perubahan selanjutnya, pakai:

```
push_ke_github.bat
```

Script itu sekarang juga ikut memperbarui `build.yml` dari `ci\build.yml.txt` secara otomatis setiap kali dijalankan, jadi workflow-nya tidak akan pernah tertinggal versi tanpa Anda sadari.

---

## Kalau Ada Yang Gagal

**`repo_baru.bat` bilang Git belum terpasang**
Unduh di [git-scm.com/download/win](https://git-scm.com/download/win), pasang dengan opsi bawaan, lalu jalankan script lagi.

**`repo_baru.bat` bilang pubspec.yaml tidak ada**
Script dijalankan dari folder yang salah. Pastikan Anda mengklik dua kali berkasnya dari dalam `D:\Kuliah_ML\Claude\kasir-laundry-source`.

**Gagal mengirim, muncul pesan authentication failed**
Login GitHub dibatalkan atau salah. Jalankan script lagi dan selesaikan proses login sampai tuntas.

**Gagal mengirim, muncul `repository not found`**
URL salah ketik, atau repo di GitHub belum dibuat. Periksa lagi langkah 1.

**Tab Actions kosong, tidak ada proses apa pun**
Folder `.github` tidak ikut terunggah. Ini seharusnya tidak terjadi lagi karena script yang memasangnya, tapi kalau tetap terjadi beri tahu saya.

**Build gagal dengan pesan `already evaluated`**
Berarti `build.yml` lama masih terpakai. Pastikan `ci\build.yml.txt` ada di folder proyek sebelum menjalankan script.

**Build gagal di langkah "Ambil dependensi"**
Kemungkinan versi paket di `pubspec.yaml` tidak lagi tersedia. Salin pesan errornya dari tab Actions dan kirim ke saya.

**Build gagal dengan `Duplicate class kotlin.*`**
Dua plugin menarik versi Kotlin standard library yang berbeda. Sudah ditangani di `android_overrides/namespace_patch.gradle`; kalau masih muncul, kirimkan nama modul yang disebut di pesan errornya.

---

## Soal Repo Lama

Repo `anggac1/kasir` tetap ada dan tidak terganggu sama sekali. Terserah Anda mau diapakan:

- **Biarkan saja** — tidak mengganggu apa pun
- **Arsipkan** — Settings → gulir ke bawah → Archive this repository, membuatnya jadi hanya-baca supaya tidak tertukar
- **Hapus** — Settings → gulir paling bawah → Delete this repository

Saya sarankan diarsipkan saja. Tidak memakan tempat, dan tetap ada kalau suatu saat perlu melihat riwayat lama.
