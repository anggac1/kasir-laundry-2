# Kasir Laundry

Aplikasi kasir laundry untuk Android. Sepenuhnya offline, tanpa login, tanpa server. Semua data tersimpan di HP dalam SQLite.

Struk dicetak lewat printer thermal Bluetooth 58mm, disetel untuk RPP02N.

Ini satu-satunya panduan. Semua yang perlu Anda tahu ada di berkas ini.

---

## Daftar Isi

1. [Dua cara memakai proyek ini](#1-dua-cara-memakai-proyek-ini)
2. [Layar terbagi tiga: kode di kiri, HP di kanan](#2-layar-terbagi-tiga-kode-di-kiri-hp-di-kanan)
3. [Pasang perkakas dari nol](#3-pasang-perkakas-dari-nol)
4. [Membuat APK lewat GitHub](#4-membuat-apk-lewat-github)
5. [Mengganti nama dan logo](#5-mengganti-nama-dan-logo)
6. [Isi aplikasi](#6-isi-aplikasi)
7. [Cara kerja template struk](#7-cara-kerja-template-struk)
8. [Kalau baris melipat di printer](#8-kalau-baris-melipat-di-printer)
9. [Perilaku yang perlu diketahui](#9-perilaku-yang-perlu-diketahui)
10. [Struktur kode](#10-struktur-kode)
11. [Ketahanan jangka panjang](#11-ketahanan-jangka-panjang)
12. [Kalau ada yang gagal](#12-kalau-ada-yang-gagal)
13. [Yang berubah di versi ini](#13-yang-berubah-di-versi-ini)

---

## 1. Dua Cara Memakai Proyek Ini

Hanya ada **dua berkas** yang perlu Anda klik. Selebihnya diurus sendiri.

| Berkas | Untuk apa |
|---|---|
| `jalankan.bat` | Mengoprek tampilan, hasilnya langsung terlihat di emulator |
| `push_ke_github.bat` | Membuat APK asli lewat GitHub Actions |

`setup_lokal.bat` ada tapi tidak perlu Anda klik — ia dipanggil sendiri oleh `jalankan.bat` saat pertama kali.

---

## 2. Layar Terbagi Tiga: Kode di Kiri, HP di Kanan

Ini yang membuat mengoprek tampilan jadi cepat.

```
┌──────────┬─────────────────────┬──────────────┐
│  Folder  │       Kode          │   Emulator   │
│          │                     │   (layar HP) │
│ lib/     │  beranda.dart       │  ┌────────┐  │
│  screens │                     │  │        │  │
│  print   │  Text('Nota Baru')  │  │ Kasir  │  │
│  db      │       ▲             │  │Laundry │  │
│          │       │             │  │        │  │
│          │   ubah di sini      │  └────────┘  │
│          │                     │   berubah    │
│          │                     │   seketika   │
└──────────┴─────────────────────┴──────────────┘
```

Setiap kali Anda menyimpan berkas dengan `Ctrl+S`, tampilan di emulator ikut berubah tanpa build ulang. Namanya **hot reload**, biasanya di bawah satu detik.

> **Jalankan `jalankan.bat` dengan klik dua kali dari File Explorer**, jangan lewat tombol Run atau Code Runner di VS Code. Panel Output VS Code tidak bisa menerima ketikan, jadi script berhenti sendiri dalam sedetik tanpa pesan apa pun — cirinya `exited with code=0` dan langkah `[1/4]` tidak pernah muncul. Kalau tetap ingin lewat VS Code, pakai Terminal VS Code (Ctrl + backtick) lalu ketik `.\jalankan.bat`. Script sekarang mendeteksi hal ini dan memberi tahu, bukan diam saja.

### Di VS Code

1. Klik dua kali `jalankan.bat`, tunggu emulator menyala dan aplikasi muncul
2. Buka VS Code → **File** → **Open Folder** → pilih folder proyek ini
3. Emulator berjalan di jendelanya sendiri. Seret jendela itu ke sisi kanan layar sampai menempel, lalu seret jendela VS Code ke sisi kiri
4. Di VS Code tekan **Ctrl+B** untuk memunculkan panel folder di kiri

Untuk hot reload tekan **Ctrl+S**, lalu tekan `r` di jendela hitam milik `jalankan.bat`.

> **Lebih praktis:** setelah emulator menyala, tekan **F5** di VS Code dan biarkan VS Code yang menjalankan aplikasinya. Dengan cara ini `Ctrl+S` langsung memicu hot reload sendiri, tidak perlu menekan `r` di mana pun.

### Di Android Studio

1. **File** → **Open** → pilih folder proyek ini
2. Di pojok kanan atas, pastikan perangkat terpilih adalah **emulator Android**, bukan "Windows (desktop)". Ini kesalahan tersering dan menghasilkan pesan `No Windows desktop project configured`
3. Tekan tombol **Run** hijau
4. Setelah aplikasi jalan, klik ikon **Running Devices** di bilah kanan. Emulator menempel di dalam jendela Android Studio sebagai panel kanan

Semuanya menyatu dalam satu jendela: Project di kiri, editor di tengah, emulator di kanan. Hot reload lewat ikon petir **⚡** atau **Ctrl+\\**.

### Kalau emulator terasa berat

Colok HP asli lewat kabel USB. Hot reload bekerja sama persis, malah lebih cepat.

HP asli **wajib** kalau menguji printer, karena emulator tidak punya Bluetooth sama sekali.

Nyalakan USB Debugging di HP: **Setelan** → **Tentang ponsel** → ketuk **Nomor bentukan** tujuh kali → kembali → **Opsi pengembang** → **USB Debugging**.

---

## 3. Pasang Perkakas dari Nol

Lewati bagian ini kalau di laptop Anda `flutter --version` sudah menampilkan `3.22.3`.

### Yang perlu diunduh

| Aplikasi | Ukuran | Kenapa |
|---|---|---|
| Git for Windows | ~300 MB | Flutter memanggilnya secara internal |
| Visual Studio Code | ~400 MB | Editor |
| Android Studio | ~5 GB | Emulator dan Android SDK |
| JDK 17 | ~190 MB | Flutter 3.22.3 tidak cocok dengan Java 21 |
| Flutter SDK 3.22.3 | ~1 GB | Versi dikunci agar sama dengan GitHub Actions |

Sediakan ruang kosong 15 GB.

### Kenapa semuanya di D:

Flutter dan Android SDK **menulis ke foldernya sendiri** saat berjalan. Di `C:\Program Files` keduanya butuh hak administrator setiap kali, dan itu memunculkan error izin yang membingungkan. Di `D:\Aplikasi` masalah itu tidak ada.

Syaratnya: **path tanpa spasi**, dan D: harus partisi internal, bukan flashdisk atau drive jaringan.

### Susunan folder

```
D:\Aplikasi\
├── flutter\        Flutter SDK 3.22.3
├── jdk17\          Java 17
└── androidsdk\     Android SDK  <-- perhatikan ejaannya
```

> **Ejaan `androidsdk`.** Folder ini memang tertulis tanpa huruf `r` pertama, hasil salah ketik saat setup Android Studio. Dibiarkan apa adanya, tidak perlu diperbaiki: `jalankan.bat` menyisir seluruh `D:\Aplikasi` untuk mencari folder yang berisi `emulator\emulator.exe`, jadi ia tetap menemukannya apa pun namanya. Kalau suatu saat Anda menamai ulang atau memindahkannya, script tetap jalan.

### Urutan pemasangan

**1. Git** — [git-scm.com/download/win](https://git-scm.com/download/win), opsi bawaan, Next sampai selesai.

**2. VS Code** — [code.visualstudio.com](https://code.visualstudio.com/). Centang **Add to PATH** dan **Open with Code**.

**3. Ekstensi VS Code.** Buka VS Code, tekan `Ctrl+Shift+X`, cari dan pasang **Flutter** (`Dart-Code.flutter`). Ekstensi Dart ikut terpasang otomatis, tidak perlu dicari terpisah.

Yang berikut ini opsional tapi membantu: **Error Lens** (pesan error muncul di sebelah barisnya), **Awesome Flutter Snippets**, **GitLens**.

Cara cepat lewat CMD, kalau tadi Anda mencentang "Add to PATH":

```
code --install-extension Dart-Code.flutter --install-extension usernamehw.errorlens
```

**4. JDK 17** — [adoptium.net/temurin/releases/?version=17](https://adoptium.net/temurin/releases/?version=17), Windows x64, paket `.msi`.

Saat wizard berjalan jangan langsung Next sampai habis. Pilih **Custom Setup** → **Change** → arahkan ke `D:\Aplikasi\jdk17` → centang **Set JAVA_HOME variable** kalau ditawarkan.

Patokan benar: ada berkas `D:\Aplikasi\jdk17\bin\java.exe`.

**5. Android Studio** — [developer.android.com/studio](https://developer.android.com/studio).

Pasang dengan lokasi bawaan. Saat pertama dibuka muncul setup wizard: pilih **Standard**, biarkan ia mengunduh SDK dan emulator. Proses ini 10–30 menit.

Saat diminta lokasi SDK, arahkan ke `D:\Aplikasi\androidsdk`.

**6. Flutter 3.22.3** — [docs.flutter.dev/install/archive](https://docs.flutter.dev/install/archive), bagian Windows, cari versi **3.22.3**.

Ekstrak ke `D:\Aplikasi\flutter`. Patokan benar: ada `D:\Aplikasi\flutter\bin\flutter.bat`. Kalau jadi `D:\Aplikasi\flutter\flutter\bin\` berarti kelebihan satu tingkat, pindahkan isinya naik.

> **Jangan pakai tombol "Download SDK" di ekstensi VS Code.** Ekstensi selalu mengambil versi stabil terbaru, sedangkan GitHub Actions kita dikunci di 3.22.3. Kalau versinya beda, folder `android/` yang dihasilkan juga beda, dan Anda bisa mengalami kode yang jalan di laptop tapi gagal di GitHub — jenis error yang paling melelahkan dilacak.

**7. Environment Variable.**

Tekan Windows → ketik `environment` → **Edit the system environment variables** → tombol **Environment Variables**.

Pakai **kotak atas** saja (*User variables*). Klik **New**:

| Variable name | Variable value |
|---|---|
| `JAVA_HOME` | `D:\Aplikasi\jdk17` |

Lalu cari baris **Path** di kotak atas → **Edit** → **New** → ketik:

```
D:\Aplikasi\flutter\bin
```

Android SDK tidak perlu ditambahkan ke Path; `jalankan.bat` mencarinya sendiri.

**8. Tutup semua jendela CMD dan VS Code, lalu buka lagi.** Wajib. Variabel baru tidak berlaku di jendela yang sudah terlanjur terbuka. Ini penyebab nomor satu dari error "perintah tidak dikenali" padahal semua sudah benar.

**9.** Buka CMD **baru** — tekan Windows, ketik `cmd`, Enter. **Jangan** pilih "Run as administrator": CMD Administrator memakai Environment Variable akun yang berbeda, sehingga `flutter` dilaporkan tidak dikenal walau semuanya sudah benar. Cirinya, CMD Administrator terbuka di `C:\Windows\System32`, sedangkan CMD biasa di `C:\Users\NamaAnda`.

```
flutter --version
```

Harus muncul `Flutter 3.22.3`. Perintah pertama bisa memakan 1–5 menit karena Flutter sedang mengunduh Dart SDK ke foldernya sendiri; ini sekali saja.

```
flutter config --jdk-dir D:\Aplikasi\jdk17
flutter doctor --android-licenses
```

Ketik `y` untuk semua pertanyaan lisensi.

**10. Buat emulator.** Android Studio → **Tools** → **Device Manager** → **Create Virtual Device** → **Pixel 4a** → pilih **API 34**.

> Hindari baris yang bertuliskan **Preview**, **beta**, **DEV**, atau **CANARY**. Versi itu sering gagal diunduh dengan pesan `404`.

**11. Selesai.** Klik dua kali `jalankan.bat`.

### Kalau Flutter terasa lambat

**Windows Defender memindai tiap berkas.** Flutter menyentuh puluhan ribu berkas kecil setiap kali berjalan, dan Defender memeriksa satu per satu. Perintah yang harusnya 3 detik bisa jadi 30 detik.

Kecualikan foldernya: Windows Security → **Virus & threat protection** → **Manage settings** → **Exclusions** → **Add an exclusion** → **Folder**:

```
D:\Aplikasi\flutter
D:\Aplikasi\androidsdk
D:\Kuliah_ML\Claude\kasir-laundry-source
```

Ini aman — yang dikecualikan hanya folder perkakas yang isinya Anda kendalikan sendiri.

**D: mungkin bukan SSD.** Banyak laptop dikirim dengan C: berupa SSD dan D: berupa HDD. Cek lewat Windows → ketik `defragment` → **Defragment and Optimize Drives**, lihat kolom *Media type*. Kalau D: ternyata HDD, build tetap berhasil tapi lebih lambat.

---

## 4. Membuat APK lewat GitHub

Build lokal butuh Gradle mengunduh ~1 GB. Kalau Anda hanya ingin APK jadi, GitHub Actions lebih praktis: gratis, dan hasilnya selalu sama.

### Pertama kali

**1.** Buka [github.com/new](https://github.com/new). Isi nama repo, misalnya `kasir-laundry`.

| Kolom | Isi |
|---|---|
| Add a README file | **jangan dicentang** |
| Add .gitignore | **jangan dipilih** |
| Choose a license | **jangan dipilih** |

Ketiganya harus kosong. Kalau dicentang, GitHub membuat commit awal sendiri dan itu berbenturan dengan unggahan kita.

**2.** Klik **Create repository**, salin URL-nya.

**3.** Klik dua kali `push_ke_github.bat`. Tempel URL (klik kanan untuk menempel, `Ctrl+V` sering tidak berfungsi di CMD), ketik `Y`.

**4.** Buka repo di browser, masuk tab **Actions**. Build berjalan otomatis, tunggu 5–10 menit sampai muncul centang hijau.

**5.** Di halaman build yang selesai, gulir ke bagian **Artifacts**, klik **kasir-laundry-apk**. Hasilnya ZIP; ekstrak, di dalamnya ada `kasir-laundry.apk`.

**6.** Kirim ke HP lewat kabel USB atau WhatsApp ke diri sendiri, lalu buka berkasnya.

> **Copot dulu aplikasi lama** sebelum memasang yang baru. Data nota akan ikut terhapus, jadi ekspor dulu lewat Pengaturan kalau masih ada nota penting.

### Perubahan berikutnya

Klik dua kali `push_ke_github.bat` lagi. URL-nya diingat, cukup tekan Enter.

Script itu juga memperbarui `.github/workflows/build.yml` dari `ci/build.yml.txt` setiap kali dijalankan, jadi workflow tidak pernah tertinggal versi tanpa Anda sadari.

### Yang tidak ikut terunggah

Repo di GitHub sengaja hanya berisi yang dibutuhkan untuk build. Berkas `.bat`, folder `_to_delete`, dan `.md` selain README ini diabaikan lewat `.gitignore`.

Folder `android/` juga tidak ikut — kerangkanya dibuat ulang otomatis oleh Flutter saat build.

---

## 5. Mengganti Nama dan Logo

Bawaannya memakai logo Flutter dengan nama **Kasir Laundry**. Ini sengaja, supaya build tidak pernah gagal walau Anda belum menyiapkan gambar sendiri.

### Nama di bawah ikon

Berkas `android_overrides/AndroidManifest.xml`:

```xml
android:label="Kasir Laundry"
```

### Judul di dalam aplikasi

Berkas `lib/main.dart`:

```dart
title: 'Kasir Laundry',
```

### Warna tema

Juga di `lib/main.dart`. Seluruh warna aplikasi diturunkan otomatis dari satu warna ini:

```dart
ColorScheme.fromSeed(seedColor: const Color(0xFF00695C))
```

### Logo

Ikon ada di `android/app/src/main/res/`, tersebar di lima folder menurut kerapatan layar:

| Folder | Ukuran |
|---|---|
| `mipmap-mdpi` | 48 x 48 |
| `mipmap-hdpi` | 72 x 72 |
| `mipmap-xhdpi` | 96 x 96 |
| `mipmap-xxhdpi` | 144 x 144 |
| `mipmap-xxxhdpi` | 192 x 192 |

Di tiap folder ada `ic_launcher.png`. Timpa kelimanya, ukurannya harus persis.

Cara praktis membuat kelima ukuran sekaligus: [icon.kitchen](https://icon.kitchen), unggah gambar, unduh hasilnya, salin isi foldernya.

> **Peringatan.** Folder `android/` dibuat ulang otomatis setiap build GitHub Actions dan setiap `jalankan.bat` berjalan di folder baru. Artinya **ikon yang Anda timpa akan hilang** saat itu terjadi. Kalau sudah mantap dengan logonya, beri tahu saya — ikonnya perlu disimpan di `android_overrides/` supaya ikut disalin otomatis seperti AndroidManifest.

---

## 6. Isi Aplikasi

**Beranda** — satu kartu hutang yang sekaligus jadi tombol saring "belum lunas", kolom pencarian, lalu daftar nota

**Nota baru** — pilih layanan dari daftar, atau isi baris manual untuk hal yang tidak punya tarif tetap seperti hutang, saldo titipan, atau tambahan pemutih. Satuan bebas diketik, boleh juga dikosongkan.

Nama pelanggan memberi saran dari nota yang pernah dibuat, jadi pelanggan langganan tidak perlu diketik ulang. Kolom harga punya tombol `+0`, `+00`, `+000` supaya tidak perlu menghitung nol satu per satu.

**Layanan** — daftar tarif. Sudah terisi sepuluh contoh, silakan ubah atau hapus.

**Template struk** — Anda mengatur sendiri mana teks tetap dan mana yang berubah. Ada pratinjau langsung di sebelahnya.

**Printer** — pilih perangkat Bluetooth, tes cetak contoh, atur lebar kertas.

**Ekspor** — PDF dan Excel untuk rekap.

**Panduan** — panduan pemakaian di dalam aplikasi, tiga bagian: Mulai untuk yang baru memasang, Masalah untuk keluhan yang sering muncul, dan Lanjutan untuk mengoprek template. Ada di menu titik tiga, paling bawah.

Tidak ada status pesanan (Diterima, Diproses, Selesai, Diambil). Sengaja dibuang: menambah tombol yang jarang dipakai, memperpanjang struk, dan tidak cocok untuk laundry yang notanya langsung selesai.

---

## 7. Cara Kerja Template Struk

Teks biasa dicetak apa adanya. Teks dalam kurung kurawal diganti data nota.

**Tag di awal baris**, boleh digabung seperti `[BC]`:

| Tag | Arti |
|---|---|
| `[L]` `[C]` `[R]` | rata kiri, tengah, kanan |
| `[B]` | tebal |
| `[H]` | huruf besar dua kali |
| `[C3]` | angka di dalam tag = ukuran huruf, 1 sampai 8 |
| `[?kunci]` | lewati baris ini kalau `{kunci}` kosong |

**Ukuran huruf.** Tambahkan angka di dalam tag: `[C2]LAUNDRY JAYA` berarti tengah dua kali besar, `[BC3]LUNAS` berarti tebal tengah tiga kali. Angka 1 sampai 8, dan tanpa angka berarti ukuran biasa — jadi template lama tidak perlu diubah, dan `[H]` sendiri masih berarti dua kali.

Makin besar hurufnya, makin sedikit yang muat sebaris. Pada kertas 32 kolom, ukuran 2 hanya muat 16 huruf dan ukuran 3 muat 10.

**Tag di tengah baris:**

`[>]` mendorong sisa teks ke kanan. `TOTAL[>]{total}` menghasilkan `TOTAL              Rp49.500`.

Baris berisi `---` menjadi garis pemisah selebar kertas.

Tag `[?kunci]` yang menghemat kertas. Baris `[?uang]Tunai[>]{uang}` hanya tercetak kalau Anda benar-benar mengisi uang yang diterima. Kalau dikosongkan, barisnya hilang sama sekali.

Daftar lengkap placeholder ada di dalam aplikasi, di layar Template Struk.

---

## 8. Kalau Baris Melipat di Printer

Kadang satu baris yang di layar jelas muat, di kertas malah jadi dua baris.

**Penyebabnya hampir selalu lebar kolom.** Aplikasi memotong baris pada angka *Lebar kertas* di Pengaturan, bawaannya **32**. Kalau printer Anda sebenarnya hanya muat 31 — misalnya karena menambah margin kiri sedikit — maka baris yang panjangnya pas 32 akan melipat.

Baris terpanjang di template bawaan panjangnya **31 karakter**, jadi sisanya cuma satu. Begitu ada nominal besar seperti `Rp1.250.000`, batas itu terlampaui.

**Perbaikannya gratis:** buka **Pengaturan** → bagian **Printer** → **Lebar kertas**. Tekan tombol minus untuk menurunkan satu angka, dari `32` jadi `31`. Ada juga pintasan angka yang sering dipakai: 30, 31, 32, 42, 48. Cetak ulang nota yang tadi melipat.

Kalau masih melipat, turunkan lagi ke `30`. Kalau sampai 30 pun masih melipat, berarti penyebabnya bukan lebar kolom — beri tahu saya.

> **Kenapa tidak dicetak sebagai gambar saja?** Itu memang menjamin baris persis seperti di layar, tapi harganya mahal: data yang dikirim ke printer membengkak **26–33 kali lipat**, sehingga cetak dua lembar naik dari 0,3 detik jadi **9–11 detik**. Baterai printer juga lebih boros dan kepalanya lebih lama panas. Menurunkan satu angka jauh lebih murah.

---

## 9. Perilaku yang Perlu Diketahui

**Total negatif jadi SISA SALDO.** Kalau pelanggan menitipkan uang lebih besar daripada tagihan, totalnya negatif. Struk mencetak nilai positif dengan label `SISA SALDO`, bukan angka minus.

**Estimasi bisa dimatikan.** Kalau nota Anda dicetak di akhir saat cucian sudah bersih, estimasi tidak ada gunanya. Matikan lewat tombol di layar nota, barisnya otomatis hilang dari struk.

**Jumlah lembar per nota.** Tiap nota bisa punya jumlah cetaknya sendiri. Kosongkan untuk mengikuti bawaan di Pengaturan.

**Status pembayaran boleh disembunyikan.** Pilihan "Sembunyi" membuat baris pembayaran tidak tercetak sama sekali.

**Waktu memakai jam HP.** Tidak ada sinkronisasi ke mana pun.

**Nomor nota tidak pernah bentrok.** Nomor diambil dari nomor tertinggi yang sudah terpakai hari itu, bukan dari jumlah nota. Jadi menghapus nota lalu membuat yang baru tidak akan menghasilkan nomor ganda.

---

## 10. Struktur Kode

```
lib/
├── main.dart              Titik masuk, tema, nama aplikasi
├── models/models.dart     Nota, ItemNota, Layanan
├── db/db.dart             SQLite, semua query
├── store/settings.dart    Pengaturan + template bawaan
├── print/
│   ├── receipt.dart       Mesin template, tag dan placeholder
│   ├── escpos.dart        Penyusun byte printer
│   └── printer_service.dart  Bluetooth
├── screens/               Semua layar
├── ui/umum.dart           Widget dan dialog yang dipakai berulang
└── utils/fmt.dart         Format rupiah, tanggal, qty
```

Yang paling sering diubah saat mengoprek tampilan: `lib/screens/`.

---

## 11. Ketahanan Jangka Panjang

Aplikasi ini dirancang supaya tetap ringan setelah dipakai bertahun-tahun, di HP dengan RAM 4 GB.

**Yang sudah diukur.** Database diisi **200.000 nota** dan 400.000 item, lalu tiap query yang dipakai aplikasi diukur. Kolom paling kanan adalah perkiraan di HP kelas bawah, yang kira-kira delapan kali lebih lambat daripada laptop:

| Yang dikerjakan | Laptop | HP kelas bawah |
|---|---|---|
| Memuat daftar nota di beranda | 0,5 ms | 4 ms |
| Menyaring "belum lunas" | 0,3 ms | 3 ms |
| Kartu hutang, hitungan pertama | 7,2 ms | 58 ms |
| Kartu hutang, sesudah disimpan | 0,002 ms | 0 ms |
| Mencari nomor nota berikutnya | 0,004 ms | 0 ms |
| Menyiapkan ekspor 30 hari | 5,6 ms | 45 ms |

Membuka aplikasi dari nol memakan sekitar **50 ms** di HP kelas bawah, jauh di bawah ambang yang mulai terasa oleh mata.

Tanpa indeks yang tepat, angka-angka itu jauh berbeda: menyaring "belum lunas" 160 ms, kartu hutang 147 ms, dan mencari nomor nota 78 ms — ketiganya cukup untuk membuat aplikasi terasa tersendat setiap kali dibuka.

**Cache dipakai secukupnya, di satu tempat saja.** Angka kartu hutang di beranda disimpan di memori, karena menghitungnya berarti membaca setiap nota yang belum lunas — sekitar 58 ms di HP lambat pada 200.000 nota, dan terus tumbuh seiring nota bertambah. Setelah disimpan, membacanya praktis nol.

Yang disimpan hanya **dua bilangan**, sekitar 100 byte, bukan salinan data. Jadi tidak menambah pemakaian memori dan tidak membuat berkas membengkak.

**Auto atau manual, Anda yang menentukan.** Di Pengaturan, bagian Beranda, ada pilihan bagaimana angka itu diperbarui:

- **Auto** (bawaan) — dihitung ulang sendiri setiap ada nota yang berubah. Selama notanya belum menumpuk, bedanya tidak terasa.
- **Manual** — tidak pernah dihitung sendiri. Tombol perbarui muncul di beranda, di sebelah kiri menu titik tiga, dengan titik kecil saat angkanya sudah berubah. Tekan saat memang perlu.

Ambang pindahnya sekitar **50.000 nota**. Di bawah itu, hitung ulang masih di bawah 12 ms bahkan di HP lambat, jadi Auto lebih nyaman. Di atas itu, Manual menghilangkan beban sepenuhnya:

| Jumlah nota | Sekali hitung, HP kelas bawah |
|---|---|
| 1.000 | 1 ms |
| 10.000 | 3 ms |
| 50.000 | 12 ms |
| 100.000 | 29 ms |
| 200.000 | 54 ms |

Pada mode Auto, angkanya dibuang setiap kali ada nota disimpan, dihapus, dilunasi, atau seluruh data dikosongkan — empat jalur itu semuanya sudah ditutup, sehingga angka di layar tidak mungkin basi.

Daftar nota sendiri **tidak** di-cache. Isinya berubah tiap kali Anda mengetik di kolom pencarian atau menekan saringan, jadi menyimpannya hanya membuang memori tanpa mempercepat apa pun.

**Dua query dijalankan bersamaan.** Saat beranda dibuka, daftar nota dan angka hutang diambil serentak, bukan bergantian. Waktu totalnya jadi yang terlama saja, bukan dijumlah.

**Yang dimuat ke memori dibatasi.** Beranda memuat 300 nota terbaru saja (~0,1 MB), bukan seluruh isi database. Layar ekspor dibatasi 5.000 nota (~5 MB termasuk itemnya). Penyaringan tanggal dikerjakan SQLite, bukan dengan menarik ribuan nota lalu membuang sebagian besarnya.

**Ekspor diproses per 500 nota.** Bukan pembatasan jumlah — kelimaribunya tetap terekspor. Android hanya mengizinkan satu perintah database membawa maksimal 999 nilai sekaligus, jadi permintaannya dipecah jadi beberapa giliran. Tanpa ini, ekspor ribuan nota gagal total dengan pesan `too many SQL variables`.

**Tiga indeks, tidak lebih.** Setiap indeks tambahan memperlambat penyimpanan nota dan membesarkan berkas database. Yang ada hanya yang benar-benar terpakai:

- urutan tanggal, untuk daftar di beranda
- gabungan status bayar + tanggal + nilai, untuk saringan dan kartu hutang sekaligus
- penghubung item ke notanya

**Berapa besar databasenya nanti.** Sekitar 258 byte per nota lengkap dengan itemnya:

| Lama dipakai | Jumlah nota | Ukuran |
|---|---|---|
| 1 tahun | 12.000 | 3 MB |
| 5 tahun | 60.000 | 15 MB |
| 10 tahun | 120.000 | 30 MB |

Perhitungan dengan asumsi seribu nota per bulan.

---

## 12. Kalau Ada Yang Gagal

### Saat menyiapkan perkakas

**`'flutter' is not recognized`**
Path belum aktif, atau Anda memakai CMD Administrator. Tutup semua CMD, buka yang biasa (tanpa "Run as administrator"), coba lagi. Kalau masih, ulangi langkah 7 dan 8 di bagian [Pasang perkakas](#3-pasang-perkakas-dari-nol).

**`Unable to locate Android SDK`**
Setup wizard Android Studio belum selesai. Buka Android Studio, biarkan wizard-nya tuntas sampai muncul "Finishing setup".

**`Unsupported class file major version 65`**
Java yang terpakai versi 21, bukan 17. Jalankan `flutter config --jdk-dir D:\Aplikasi\jdk17`.

**`Waiting for another flutter command to release the startup lock`**
Ada proses `dart.exe` yang tersangkut. Buka Task Manager, akhiri semua `dart.exe`, lalu hapus berkas `D:\Aplikasi\flutter\bin\cache\lockfile`.

**Unduhan sistem image gagal dengan `404`**
Anda memilih versi Preview, beta, DEV, atau CANARY. Pilih **API 34** yang stabil.

### Saat menjalankan

**`No Windows desktop project configured`**
Android Studio atau VS Code memilih Windows, bukan emulator. Ganti perangkat tujuan di pojok kanan atas.

**`No supported devices connected`**
Emulator belum menyala atau sudah mati. Jalankan `jalankan.bat`, tunggu sampai layar Home Android muncul.

**Emulator tidak ada di daftar**
Buat dulu lewat Android Studio → **Tools** → **Device Manager** → **Create Virtual Device**.

**`jalankan.bat` langsung selesai, `exited with code=0` dalam sedetik**
Dijalankan lewat Code Runner di VS Code. Panel Output tidak bisa menerima ketikan, jadi script berhenti saat menunggu jawaban Anda. Klik dua kali berkasnya dari File Explorer, atau pakai Terminal VS Code lalu ketik `.\jalankan.bat`.

**`jalankan.bat` bilang Android SDK tidak ketemu**
Script sudah menyisir seluruh `D:\Aplikasi`. Kalau tetap gagal, ia akan meminta Anda menempel lokasinya langsung di jendela itu — salin dari Android Studio → **Settings** → **Languages & Frameworks** → **Android SDK**, lihat kotak *Android SDK Location*.

### Saat mengunggah ke GitHub

**`pubspec.yaml tidak ada`**
Script dijalankan dari folder yang salah. Klik dua kali berkasnya dari dalam folder proyek.

**`repository not found`**
URL salah ketik, atau repo belum dibuat di GitHub.

**`authentication failed`**
Login GitHub dibatalkan. Jalankan script lagi dan selesaikan proses login sampai tuntas.

**Tab Actions kosong**
Folder `.github` tidak ikut terunggah. Seharusnya tidak terjadi karena script yang memasangnya; kalau tetap terjadi beri tahu saya.

### Saat build di GitHub Actions

**Gagal dengan `403 Forbidden`**
Repositori Maven menolak permintaan dari runner. Sudah ditangani lewat mirror Google di `ci/build.yml.txt`, dan build diulang otomatis sampai tiga kali. Kalau masih gagal, jalankan ulang workflow-nya dari tab Actions.

**Gagal dengan `Duplicate class kotlin.*`**
Dua plugin menarik versi Kotlin yang berbeda. Sudah ditangani di `android_overrides/namespace_patch.gradle`.

**Gagal dengan `already evaluated`**
`build.yml` versi lama masih terpakai. Pastikan `ci\build.yml.txt` ada di folder proyek sebelum menjalankan script.

**Gagal lainnya**
Salin pesan errornya dari tab Actions dan kirim ke saya.

### Saat mencetak

**Printer tidak muncul di daftar**
Pasangkan dulu lewat Setelan Bluetooth HP. Aplikasi hanya membaca perangkat yang sudah terpasang, tidak memindai sendiri.

**Layar printer berputar terus**
Semua panggilan Bluetooth sudah dibatasi waktunya, jadi seharusnya selalu berhenti dengan pesan. Kalau tetap berputar, APK yang terpasang masih versi lama — copot dan pasang ulang.

**Cetak gagal di tengah**
Muncul dialog berisi rincian tiap langkah. Foto dialog itu dan kirim ke saya; penyebabnya pasti ada di salah satu barisnya.

**Baris melipat**
Lihat bagian [Kalau baris melipat di printer](#8-kalau-baris-melipat-di-printer).

---

## Catatan Teknis

Flutter dikunci di versi **3.22.3** supaya hasil build di laptop dan di GitHub Actions selalu sama.

Aplikasi **tidak meminta izin INTERNET**. Tanpa izin itu, Android sendiri yang memblokir segala koneksi keluar, jadi data Anda dijamin tidak ke mana-mana. Yang diminta hanya Bluetooth, dan itu pun baru saat Anda menekan tombol yang membutuhkannya.

---

## 13. Yang Berubah di Versi Ini

Daftar perubahan terbaru, supaya Anda tidak perlu menebak apa yang baru.

### Tampilan

**Beranda dirapikan jadi satu baris.** Dua kotak dan chip saringan digabung jadi satu kartu: nominal hutang di kiri, jumlah nota di bawahnya, ikon saringan di kanan. Menekan kartunya langsung menyaring nota yang belum lunas.

**Ukuran huruf mengikuti HP, bukan dipaksa.** Semua teks memakai gaya tema, jadi ikut setelan *Ukuran Tampilan* di HP Anda. Memaksa huruf besar justru membuatnya terpotong di layar sempit. Nominal rupiah mengecil sendiri hanya kalau benar-benar tidak muat.

**Daftar nota lebih rapat.** Satu layar HP kecil sekarang memuat 7–8 pelanggan, sebelumnya 5–6.

**Keyboard tidak lagi menutupi isian.** Berlaku di layar nota baru dan di lembar pilih layanan — kolom carinya dulu tertutup persis saat mulai mengetik.

### Mengisi nota

**Nama pelanggan memberi saran.** Ketik dua huruf, nama yang pernah dipakai akan muncul dengan ikon jam. Tekan silang di sebelahnya kalau ada nama salah ketik yang mengganggu — notanya tetap utuh, hanya tidak disarankan lagi. Kembalikan lewat Pengaturan → Beranda → Saran nama pelanggan.

**Tombol nol untuk harga.** Ketik `7`, tekan `+000`, jadi `7000`. Ada `+0`, `+000`, dan `C` untuk hapus. Terpasang di harga item, harga layanan, dan uang diterima.

**Isian wajib ditandai bintang merah**, seperti di formulir online. Yang wajib hanya nama pelanggan, nama item, jumlah, dan harga.

### Printer

**Printer naik ke menu titik tiga**, tidak lagi terkubur di dalam Pengaturan.

**Kalau gagal mencetak, bisa dibereskan di tempat.** Muncul dialog dengan tombol **Setelan Bluetooth** — nyalakan Bluetooth atau pasangkan printer, tekan kembali, lalu **Coba Cetak Lagi**. Nota sudah tersimpan sebelum mencetak, jadi tidak ada isian yang hilang. Kalau memilih Nanti Saja, notanya tetap bisa dicetak dari beranda.

**Lebar kertas akhirnya bisa diatur.** Sebelumnya hanya ada dua tombol, 58mm dan 80mm — angka 31 atau 30 tidak bisa dipilih sama sekali. Sekarang ada tombol minus/plus satuan plus pintasan 30, 31, 32, 42, 48.

**Ukuran huruf di struk bisa diatur.** Tambahkan angka di dalam tag: `[C2]` tengah dua kali besar, `[BC3]` tebal tengah tiga kali. Angka 1 sampai 8. Template lama tidak perlu diubah.

### Soal ukuran aplikasi

APK dari GitHub Actions sekitar **22,5 MB**, tapi di HP terbaca sekitar **50 MB**. Ini wajar, bukan tanda ada yang salah.

Dua sebabnya. Pertama, APK itu berkas ZIP terkompresi, dan Android membongkarnya saat memasang — biasanya mengembang 1,4 sampai 1,6 kali. Kedua, APK ini berisi kode untuk tiga jenis prosesor sekaligus (arm64, arm32, x86_64) supaya satu berkas bisa dipasang di HP mana pun, lalu Android menyimpan salinan kode itu di luar APK dan membuat cache supaya aplikasi cepat dibuka.

Kalau suatu saat ukurannya terasa mengganggu, build bisa dipecah per prosesor (`--split-per-abi`) sehingga APK jadi sekitar 9–10 MB dan di HP sekitar 22–25 MB. Konsekuensinya Anda harus memilih berkas yang tepat untuk tiap HP, jadi belum saya terapkan.
