# Setup Testing di Laptop

Panduan menyiapkan lenovo Anda supaya bisa menjalankan dan mengubah aplikasi ini sendiri, tanpa bergantung GitHub Actions.

Kalau Anda hanya ingin APK jadi tanpa mengubah kode, lewati panduan ini — pakai GitHub Actions seperti di README.

---

## PENTING: Perintah Dijalankan di Mana?

Panduan ini banyak berisi perintah. **Setiap blok perintah selalu diawali keterangan jendela mana yang harus dibuka.** Ada dua jenis, dan keduanya berbeda.

### Jendela A — Command Prompt (CMD)

Jendela hitam bawaan Windows. Dipakai untuk semua perintah **setup**, yang tidak ada hubungannya dengan folder proyek.

**Cara membuka:** tekan tombol **Windows** di keyboard → ketik `cmd` → tekan **Enter** langsung.

Akan muncul jendela hitam dengan tulisan seperti `C:\Users\NamaAnda>`. Ketik atau tempel perintahnya di situ, lalu Enter.

> **JANGAN pilih "Run as administrator".** Ini jebakan yang paling sering bikin pusing.
>
> CMD Administrator berjalan sebagai akun Administrator, yang punya Environment Variable sendiri. PATH yang Anda buat di *User variables* tidak terlihat dari sana, jadi `flutter` akan dilaporkan tidak dikenal padahal semuanya sudah benar.
>
> **Cara mengenalinya:** CMD biasa terbuka di `C:\Users\NamaAnda`. Kalau terbuka di `C:\Windows\System32`, itu CMD Administrator — tutup dan buka yang biasa. Setup Flutter tidak pernah butuh hak administrator.

> Untuk menempel di CMD, klik kanan di dalam jendelanya. `Ctrl+V` kadang tidak berfungsi di CMD versi lama.

### Jendela B — Terminal di dalam VS Code

Terminal yang menyatu dengan VS Code. Dipakai untuk perintah yang **berhubungan dengan folder proyek**, karena posisinya otomatis sudah berada di folder itu.

**Cara membuka:** buka folder proyek di VS Code, lalu tekan **Ctrl + `** (tombol backtick, di kiri angka 1). Atau lewat menu **Terminal → New Terminal**.

### Dua aturan yang wajib diingat

**Setelah mengubah Environment Variable, tutup SEMUA jendela CMD dan VS Code, lalu buka lagi.** Variabel baru tidak berlaku di jendela yang sudah terlanjur terbuka. Ini penyebab nomor satu dari error "perintah tidak dikenali" padahal semua sudah dipasang benar.

**Untuk membuka CMD langsung di suatu folder:** buka foldernya di File Explorer, klik kolom alamat di bagian atas sampai teksnya tersorot, ketik `cmd`, lalu Enter. CMD terbuka sudah berada di folder itu — tidak perlu mengetik `cd` panjang-panjang.

---

## Apakah Aman Menaruh Semuanya di D:\Aplikasi?

**Aman, dan untuk Flutter justru lebih baik daripada `C:\Program Files`.**

Flutter dan Android SDK **menulis ke foldernya sendiri** saat berjalan — Flutter menyimpan cache engine di dalam foldernya, dan `sdkmanager` menambah komponen ke folder SDK. Di `C:\Program Files` keduanya butuh hak administrator setiap kali, yang menimbulkan error izin membingungkan. Di `D:\Aplikasi` masalah itu tidak ada.

Tiga syarat yang harus dipenuhi:

**Path tidak boleh ada spasi.** `D:\Aplikasi` sudah benar. Jangan `D:\Program Files` atau `D:\Aplikasi Saya` — Gradle dan NDK punya sejarah panjang gagal pada path berspasi, dan pesan errornya tidak pernah menyebut spasi sebagai penyebab.

**D: harus partisi internal, bukan flashdisk atau harddisk eksternal.** Kalau drive-nya dicabut, semua PATH menunjuk ke tempat yang tidak ada.

**Bukan drive jaringan.** Gradle sangat lambat dan sering gagal kalau file-nya di share jaringan.

### Yang tetap ke C: kalau tidak diatur

Tiga cache ini defaultnya ke C: dan totalnya bisa 3–6 GB:

| Cache | Lokasi bawaan | Ukuran |
|---|---|---|
| Gradle | `C:\Users\<nama>\.gradle` | 2–5 GB |
| Pub (paket Dart) | `C:\Users\<nama>\AppData\Local\Pub\Cache` | 300 MB–1 GB |
| Android adb & AVD | `C:\Users\<nama>\.android` | kecil |

Kalau C: Anda lega, biarkan saja. Kalau sempit, dua yang pertama bisa dipindah lewat environment variable — caranya di langkah 7.

---

## Yang Perlu Diunduh

Panduan ini sengaja **menghindari Android Studio**. Aplikasi itu berukuran 4 GB lebih, dan satu-satunya yang kita butuhkan darinya adalah Android SDK, yang bisa dipasang sendiri sebesar 700 MB.

**Hanya 2 aplikasi yang benar-benar diinstal:**

| Aplikasi | Ukuran | Kenapa perlu installer |
|---|---|---|
| Visual Studio Code | ~400 MB | Editor utama |
| Git for Windows | ~300 MB | Flutter memanggilnya secara internal |

**Sisanya cuma ZIP yang diekstrak** — tidak muncul di Add/Remove Programs, tidak menyentuh registry, cukup dihapus foldernya kalau tidak dipakai lagi:

| Komponen | Unduh | Setelah ekstrak |
|---|---|---|
| Flutter SDK 3.22.3 | ~1 GB | ~2,5 GB |
| JDK 17 | ~190 MB | ~300 MB |
| Android cmdline-tools | ~150 MB | ~700 MB dengan komponennya |

> **Soal JDK 17:** halaman utama Temurin hanya menonjolkan format `.msi`. Itu tidak masalah — Java tidak menulis ke foldernya sendiri, jadi installer aman dan lokasinya pun bisa diarahkan ke D: saat wizard berjalan. Kalau tetap mau versi ZIP, ada di Microsoft Build of OpenJDK. Ketiga jalurnya di langkah 5.

**Total sekitar 4 GB**, bukan 11 GB seperti kalau memakai Android Studio. Sediakan ruang kosong 10 GB di D: supaya lega saat build.

Emulator Android tidak diunduh — hemat 8 GB lagi. Testing pakai HP asli lewat kabel USB lebih cepat, dan wajib kalau mau menguji printer Bluetooth karena emulator tidak punya Bluetooth sama sekali.

### Susunan folder yang dituju

```
D:\Aplikasi\
├── flutter\           Flutter SDK 3.22.3
├── jdk17\             Java 17
├── android-sdk\       Android SDK
│   ├── cmdline-tools\latest\
│   ├── platform-tools\
│   ├── platforms\android-34\
│   └── build-tools\34.0.0\
└── cache\             opsional, pemindahan cache dari C:
    ├── gradle\
    └── pub\
```

---

## 1. Visual Studio Code

**Unduh:** [code.visualstudio.com](https://code.visualstudio.com/)

Saat memasang, centang **"Add to PATH"** dan **"Open with Code"** pada menu klik kanan.

> Kalau Anda benar-benar tidak ingin ada installer sama sekali, VS Code juga tersedia dalam versi **.zip portable** di halaman unduh yang sama. Ekstrak ke `D:\Aplikasi\VSCode`. Konsekuensinya menu klik kanan "Open with Code" tidak ada, dan `code` harus ditambahkan ke PATH manual.

---

## 2. Ekstensi VS Code

**Di mana:** di dalam **VS Code**, bukan CMD.

Buka VS Code, tekan `Ctrl+Shift+X` (ikon kotak-kotak di bilah kiri), lalu cari dan pasang.

### Wajib

| Ekstensi | ID | Fungsi |
|---|---|---|
| **Flutter** | `Dart-Code.flutter` | Menjalankan, debug, hot reload |

Memasang **Flutter** saja sudah cukup — ekstensi **Dart** (`Dart-Code.dart-code`) ikut terpasang otomatis sebagai dependensi. Tidak perlu dicari terpisah.

### Sangat membantu

| Ekstensi | ID | Kenapa berguna |
|---|---|---|
| **Error Lens** | `usernamehw.errorlens` | Pesan error muncul di sebelah baris kodenya, tidak perlu buka panel Problems |
| **Awesome Flutter Snippets** | `Nash.awesome-flutter-snippets` | Ketik `statefulW` lalu Tab, kerangka widget langsung jadi |
| **Pubspec Assist** | `jeroen-meijer.pubspec-assist` | Menambah paket lewat pencarian, versinya diisi otomatis |
| **GitLens** | `eamodio.gitlens` | Melihat siapa mengubah baris apa dan kapan |
| **Material Icon Theme** | `PKief.material-icon-theme` | Ikon file yang lebih mudah dibedakan |

### Cara cepat memasang semuanya sekaligus

> **Jendela A — Command Prompt.** Tombol Windows → ketik `cmd` → Enter.
> Hanya bisa dipakai kalau tadi Anda mencentang "Add to PATH" saat memasang VS Code.

```
code --install-extension Dart-Code.flutter --install-extension usernamehw.errorlens --install-extension Nash.awesome-flutter-snippets --install-extension jeroen-meijer.pubspec-assist --install-extension eamodio.gitlens --install-extension PKief.material-icon-theme
```

Kalau muncul `'code' is not recognized`, lewati saja cara cepat ini dan pasang manual lewat `Ctrl+Shift+X` di VS Code.

---

## 3. Git for Windows

**Unduh:** [git-scm.com/download/win](https://git-scm.com/download/win)

Pasang dengan opsi bawaan, klik Next sampai selesai. Flutter memakai Git secara internal untuk mengelola versinya sendiri, jadi ini wajib walaupun Anda tidak berencana memakai Git langsung.

Installer-nya menaruh diri di C: dan itu tidak masalah — Git tidak menulis apa-apa ke foldernya sendiri saat berjalan.

---

## 4. Flutter SDK 3.22.3

**Unduh:** [docs.flutter.dev/install/archive](https://docs.flutter.dev/install/archive) → bagian Windows → cari **3.22.3**

Ekstrak ke `D:\Aplikasi\flutter`.

**Patokan benar:** ada berkas `D:\Aplikasi\flutter\bin\flutter.bat`
**Kalau salah:** jadi `D:\Aplikasi\flutter\flutter\bin\flutter.bat` — ada kata flutter dua kali. Pindahkan isi folder dalam naik satu level.

> **Kenapa tidak lewat ekstensi VS Code saja?**
>
> Ekstensi Flutter memang bisa mengunduh SDK sendiri (`Ctrl+Shift+P` → `Flutter: New Project` → **Download SDK**), dan itu resmi didukung. Masalahnya ekstensi selalu mengambil **versi stabil terbaru**, sedangkan GitHub Actions kita dikunci ke **3.22.3**.
>
> Kalau versinya beda, folder `android/` yang dihasilkan juga berbeda, dan Anda bisa mengalami kode yang jalan di laptop tapi gagal di GitHub. Itu jenis error yang paling melelahkan dilacak.

---

## 5. JDK 17

Java 17 dipilih karena Flutter 3.22.3 dan Gradle-nya tidak cocok dengan Java 21. Ketidakcocokan ini muncul sebagai error `Unsupported class file major version 65` yang sama sekali tidak menyebut Java sebagai penyebabnya.

### Installer .msi tidak masalah untuk Java

Berbeda dengan Flutter dan Android SDK, **Java tidak pernah menulis ke foldernya sendiri** saat berjalan. Jadi memasangnya lewat installer, bahkan ke `C:\Program Files`, tidak menimbulkan masalah izin. Aturan "hindari Program Files" di panduan ini hanya berlaku untuk Flutter dan Android SDK.

Tiga pilihan, semuanya benar:

**Pilihan A — pakai .msi, arahkan ke D: (paling praktis)**

[adoptium.net/temurin/releases/?version=17](https://adoptium.net/temurin/releases/?version=17) → Windows x64 → unduh **.msi**

Saat wizard berjalan, jangan langsung Next sampai habis. Pilih **Custom Setup** → klik tombol **Change...** → arahkan ke `D:\Aplikasi\jdk17`. Aktifkan juga opsi **Set JAVA_HOME variable** kalau ditawarkan, itu menghemat satu langkah di nomor 7.

**Pilihan B — Microsoft Build of OpenJDK, tersedia .zip**

[learn.microsoft.com/java/openjdk/download](https://learn.microsoft.com/en-us/java/openjdk/download) → cari baris **Java 17 → Windows x64 → zip**

OpenJDK yang sama, hanya dikemas Microsoft, sepenuhnya kompatibel untuk build Android.

**Pilihan C — Temurin .zip dari GitHub**

[github.com/adoptium/temurin17-binaries/releases](https://github.com/adoptium/temurin17-binaries/releases) → cari `OpenJDK17U-jdk_x64_windows_hotspot_*.zip`

### Apa pun pilihannya

**Patokan benar:** ada berkas `D:\Aplikasi\jdk17\bin\java.exe`

> Hati-hati kalau memilih ZIP: isinya biasanya sudah terbungkus folder bernama `jdk-17.0.x+y`. Ekstrak apa adanya menghasilkan `D:\Aplikasi\jdk17\jdk-17.0.13+11\bin\java.exe` — satu tingkat terlalu dalam. Pindahkan isinya naik satu level.

Cek hasilnya:

> **Jendela A — Command Prompt.**

```
D:\Aplikasi\jdk17\bin\java -version
```

Harus muncul tulisan `openjdk version "17.x.x"`. Kalau muncul `system cannot find the path`, berarti struktur foldernya belum benar.

---

## 6. Android SDK tanpa Android Studio

**Unduh:** [developer.android.com/studio](https://developer.android.com/studio) → gulir jauh ke bawah ke bagian **"Command line tools only"** → ambil versi Windows

> Jangan ambil tombol besar Android Studio di bagian atas halaman. Yang kita butuhkan ada di tabel kecil jauh di bawah.

### Susunan foldernya rewel, ikuti persis

ZIP-nya berisi folder bernama `cmdline-tools`. Google mewajibkan struktur berikut, dan kalau salah, `sdkmanager` menolak berjalan dengan pesan yang tidak menjelaskan apa-apa:

```
D:\Aplikasi\android-sdk\cmdline-tools\latest\bin\sdkmanager.bat
```

Perhatikan kata **`latest`** di tengah. Langkahnya, semua lewat File Explorer biasa:

1. Buat folder `D:\Aplikasi\android-sdk\cmdline-tools`
2. Ekstrak ZIP yang tadi diunduh, akan muncul folder bernama `cmdline-tools`
3. **Ganti nama** folder hasil ekstrak itu menjadi `latest`
4. Pindahkan folder `latest` ke dalam `D:\Aplikasi\android-sdk\cmdline-tools`

**Patokan benar:** buka `D:\Aplikasi\android-sdk\cmdline-tools\latest\bin` — harus ada berkas `sdkmanager.bat` di dalamnya.

### Pasang komponennya

> **Jendela A — Command Prompt.** Tombol Windows → ketik `cmd` → Enter.
> Ketik baris pertama, Enter, lalu baris kedua, Enter, dan seterusnya. Jangan ditempel sekaligus.

```
set JAVA_HOME=D:\Aplikasi\jdk17
```

```
cd /d D:\Aplikasi\android-sdk\cmdline-tools\latest\bin
```

```
sdkmanager --sdk_root=D:\Aplikasi\android-sdk "platform-tools" "platforms;android-34" "build-tools;34.0.0"
```

Unduhan berjalan beberapa menit. Kalau ada pertanyaan lisensi, ketik `y` lalu Enter.

Setelah selesai, masih di jendela CMD yang sama:

```
sdkmanager --sdk_root=D:\Aplikasi\android-sdk --licenses
```

Ketik `y` lalu Enter untuk setiap pertanyaan sampai habis.

Selesai. Anda baru saja menghemat 4 GB dan satu aplikasi besar.

> `flutter doctor` nanti akan menandai **Android Studio: not installed**. Itu peringatan, bukan error — abaikan selama baris **Android toolchain** bercentang hijau.

---

## 7. Environment Variable

**Di mana:** jendela pengaturan Windows, bukan CMD.

Tekan tombol **Windows** → ketik `environment` → pilih **Edit the system environment variables** → di jendela yang muncul klik tombol **Environment Variables...**

Akan muncul jendela dengan dua kotak bertumpuk. **Kita hanya memakai kotak ATAS**, yang berjudul *User variables for [nama Anda]*.

### 7a. Buat variabel baru

Di kotak atas, klik tombol **New...** untuk masing-masing baris berikut. Isi kolom *Variable name* dan *Variable value*, lalu OK.

| Variable name | Variable value |
|---|---|
| `JAVA_HOME` | `D:\Aplikasi\jdk17` |
| `ANDROID_HOME` | `D:\Aplikasi\android-sdk` |
| `ANDROID_SDK_ROOT` | `D:\Aplikasi\android-sdk` |

Kalau tadi Anda memasang JDK lewat .msi dan mencentang "Set JAVA_HOME", variabel `JAVA_HOME` mungkin sudah ada. Klik **Edit** dan pastikan isinya `D:\Aplikasi\jdk17`.

Dua variabel berikut **opsional**, isi kalau ingin cache besar tidak menumpuk di C:

| Variable name | Variable value |
|---|---|
| `GRADLE_USER_HOME` | `D:\Aplikasi\cache\gradle` |
| `PUB_CACHE` | `D:\Aplikasi\cache\pub` |

Buat dulu folder `D:\Aplikasi\cache\gradle` dan `D:\Aplikasi\cache\pub` lewat File Explorer sebelum mengisi variabelnya.

### 7b. Tambahkan ke Path

Masih di kotak atas, cari baris bernama **Path** → klik sekali untuk menyorotnya → klik **Edit...**

Muncul jendela berisi daftar. Klik **New** lalu ketik satu baris, ulangi tiga kali:

```
D:\Aplikasi\flutter\bin
```
```
D:\Aplikasi\android-sdk\platform-tools
```
```
D:\Aplikasi\android-sdk\cmdline-tools\latest\bin
```

Klik **OK** di ketiga jendela sampai semuanya tertutup.

### 7c. Tutup semua jendela

**Ini wajib, jangan dilewati.** Tutup semua Command Prompt dan VS Code yang sedang terbuka. Variabel baru tidak berlaku di jendela yang sudah terlanjur jalan.

---

## 8. Beri Tahu Flutter Lokasi SDK

> **Jendela A — Command Prompt BARU.** Tombol Windows → ketik `cmd` → Enter.
> Harus jendela yang baru dibuka setelah langkah 7c, bukan yang lama.

Cek dulu Flutter sudah terbaca:

```
flutter --version
```

Harus muncul `Flutter 3.22.3`. Kalau muncul `'flutter' is not recognized`, berarti Path belum tersimpan atau jendelanya belum ditutup-buka — ulangi langkah 7b dan 7c.

Kalau sudah benar, lanjutkan di jendela yang sama:

```
flutter config --android-sdk D:\Aplikasi\android-sdk
```

```
flutter config --jdk-dir D:\Aplikasi\jdk17
```

Dua perintah ini menyimpan lokasi SDK ke dalam pengaturan Flutter, jadi hanya perlu dijalankan **sekali seumur hidup** di laptop ini. Tidak perlu diulang tiap kali membuka proyek.

Setujui lisensi Android, masih di jendela yang sama:

```
flutter doctor --android-licenses
```

Ketik `y` lalu Enter untuk setiap pertanyaan.

---

## 9. Memeriksa Kesiapan

> **Jendela A — Command Prompt.**

```
flutter doctor -v
```

Yang perlu bercentang hijau hanya dua:

- **Flutter**
- **Android toolchain**

Yang lain boleh diabaikan:

- **Android Studio: not installed** — memang sengaja, kita pakai command-line tools
- **Visual Studio** — itu untuk aplikasi Windows desktop, bukan Android
- **Chrome** — untuk Flutter Web

### Kalau ada yang merah

**`'flutter' is not recognized`**
Path belum aktif. Ulangi langkah 7b, lalu tutup semua CMD dan buka baru.

**`Unable to locate Android SDK`**
Ulangi `flutter config --android-sdk D:\Aplikasi\android-sdk` di langkah 8.

**`cmdline-tools component is missing`**
Struktur foldernya salah. Harus persis `android-sdk\cmdline-tools\latest\bin\sdkmanager.bat` — perhatikan kata `latest` di tengah. Ulangi langkah 6.

**`Android license status unknown`**
Jalankan `flutter doctor --android-licenses`, ketik `y` untuk semua pertanyaan.

**`Unsupported class file major version 65`**
Java yang terpakai versi 21. Cek `JAVA_HOME` menunjuk ke `D:\Aplikasi\jdk17`, lalu ulangi `flutter config --jdk-dir D:\Aplikasi\jdk17`.

---

## 9b. Kalau Flutter Terasa Lambat

### Perintah pertama memang lama, itu wajar

`flutter --version` yang pertama kali bisa memakan 1–5 menit. Flutter sedang **mengunduh dan mengekstrak Dart SDK beserta engine-nya** ke dalam foldernya sendiri, sekitar 300–600 MB. Ini hanya terjadi sekali.

Perintah kedua dan seterusnya seharusnya **2–5 detik**. Kalau tetap belasan detik setiap kali, ada dua penyebab yang bisa diperbaiki.

### Penyebab 1: Windows Defender memindai tiap berkas

Ini biang keladi yang paling besar di Windows. Flutter, Dart, dan Gradle menyentuh **puluhan ribu berkas kecil** setiap kali berjalan, dan Defender memindai satu per satu secara real-time. Efeknya bisa membuat perintah yang harusnya 3 detik menjadi 30 detik.

Perbaikannya dengan mengecualikan folder kerja dari pemindaian:

**Di mana:** tombol Windows → ketik `Windows Security` → Enter → **Virus & threat protection** → di bawah tulisan *Virus & threat protection settings* klik **Manage settings** → gulir ke bawah sampai **Exclusions** → **Add or remove exclusions** → **Add an exclusion** → **Folder**

Tambahkan folder-folder ini satu per satu:

```
D:\Aplikasi\flutter
D:\Aplikasi\android-sdk
D:\Aplikasi\cache
D:\Kuliah_ML\Claude\kasir-laundry-source
```

Kalau Anda tidak memindahkan cache ke D:, ganti baris ketiga dengan dua folder ini:

```
C:\Users\<nama>\.gradle
C:\Users\<nama>\AppData\Local\Pub\Cache
```

Ini aman. Yang dikecualikan hanya folder tool pengembangan yang isinya Anda kendalikan sendiri, bukan folder unduhan atau dokumen.

### Penyebab 2: D: mungkin bukan SSD

Banyak laptop, termasuk sebagian Lenovo, dikirim dengan **C: berupa SSD dan D: berupa HDD biasa**. Kalau begitu keadaannya, semua yang kita taruh di D: memang berjalan jauh lebih lambat — HDD sangat payah untuk pola baca-tulis banyak berkas kecil, dan itulah persis pola kerja Flutter.

**Cara mengecek:** tombol Windows → ketik `defragment` → buka **Defragment and Optimize Drives**. Di kolom *Media type* akan tertulis **Solid state drive** atau **Hard disk drive** untuk tiap partisi.

Kalau D: ternyata HDD, ada dua pilihan jujur:

- **Biarkan saja.** Build tetap berhasil, hanya lebih lama. Untuk proyek sekecil ini masih tertahankan.
- **Pindahkan `D:\Aplikasi` ke C:** kalau C: adalah SSD dan ruangnya cukup, misalnya ke `C:\Aplikasi`. Semua aturan di panduan ini tetap berlaku — yang penting path-nya tanpa spasi dan bukan di dalam `C:\Program Files`. Anda perlu memperbarui Environment Variable dan mengulang `flutter config`.

### Percepatan kecil lainnya

> **Jendela A — Command Prompt.**

Matikan pengiriman statistik penggunaan, menghilangkan satu panggilan jaringan tiap perintah:

```
flutter config --no-analytics
```

Unduh semua artefak build sekarang, supaya tidak diunduh mendadak saat `flutter run` pertama:

```
flutter precache --android
```

### Yang memang lambat dan tidak bisa dipercepat

**`flutter run` pertama kali: 5–15 menit.** Gradle mengunduh sekitar 1 GB dependensi Android. Ini sekali saja per proyek; setelahnya tersimpan di cache. Jangan dibatalkan di tengah jalan — cache yang rusak harus dihapus manual dan diunduh ulang dari nol.

**Hot reload tetap cepat.** Setelah aplikasi berjalan, menekan `r` memakan waktu kurang dari sedetik berapa pun lambatnya build pertama tadi. Itu bagian yang paling sering Anda pakai.

---

## 10. Menyiapkan HP

**Di mana:** di HP Anda, bukan di laptop.

1. Buka **Setelan** → **Tentang ponsel**
2. Cari **Nomor bentukan** (Build number), ketuk **tujuh kali** sampai muncul pesan "Anda sekarang seorang pengembang"
3. Kembali ke Setelan → cari **Opsi pengembang** → nyalakan **USB Debugging**
4. Colok HP ke laptop dengan kabel USB **yang mendukung transfer data** — banyak kabel murah hanya bisa mengisi daya, dan ini penyebab HP tidak terdeteksi yang paling sering
5. Di layar HP muncul dialog "Izinkan USB debugging?" → centang **Selalu izinkan** → **OK**

Cek dari laptop:

> **Jendela A — Command Prompt.**

```
flutter devices
```

Kalau HP Anda muncul di daftar, siap dipakai.

**Kalau tidak muncul:** geser panel notifikasi di HP, cari notifikasi USB, ubah modenya dari "Mengisi daya" menjadi **"Transfer file (MTP)"**. Sebagian merek juga butuh driver tambahan — cari **"[merek HP Anda] USB driver"**.

---

## 11. Menjalankan Proyek

### 11a. Sekali di awal

Folder `android/` sengaja tidak ada di repo karena dibuat otomatis oleh Flutter.

**Di mana:** File Explorer. Buka folder proyek `D:\Kuliah_ML\Claude\kasir-laundry-source`, lalu **klik dua kali** berkas:

```
setup_lokal.bat
```

Jendela hitam akan terbuka sendiri dan berjalan otomatis. Tunggu sampai muncul tulisan "Selesai", lalu tekan sembarang tombol untuk menutupnya.

Script itu membuat kerangka Android, memasang AndroidManifest yang benar, menambal namespace plugin, lalu mengambil dependensi. Cukup sekali, tidak perlu diulang.

### 11b. Membuka proyek di VS Code

Klik kanan folder `kasir-laundry-source` di File Explorer → **Open with Code**.

Kalau menu itu tidak ada: buka VS Code → menu **File** → **Open Folder...** → pilih folder tersebut.

### 11c. Menjalankan ke HP

> **Jendela B — Terminal VS Code.** Tekan **Ctrl + `** (backtick, di kiri angka 1).
> Terminal ini otomatis sudah berada di folder proyek, jadi tidak perlu `cd` ke mana-mana.

```
flutter run
```

Atau lebih mudah: cukup tekan **F5** tanpa mengetik apa pun.

Build pertama 5–15 menit karena Gradle mengunduh sekitar 1 GB. Yang berikutnya jauh lebih cepat.

### 11d. Hot reload

Saat aplikasi sudah jalan di HP, **terminalnya jangan ditutup**. Ubah kode di VS Code, simpan dengan `Ctrl+S`, lalu klik terminal dan tekan:

| Tombol | Fungsi |
|---|---|
| **`r`** | Hot reload — perubahan muncul di HP dalam hitungan detik |
| **`R`** | Restart penuh aplikasi |
| **`q`** | Berhenti |

Hot reload inilah alasan utama setup lokal sepadan dengan usahanya. Menunggu GitHub Actions 10 menit hanya untuk mengubah satu baris teks jelas tidak masuk akal.

### 11e. Membuat APK

> **Jendela B — Terminal VS Code.**

```
flutter build apk --release
```

Hasilnya di `build\app\outputs\flutter-apk\app-release.apk` di dalam folder proyek.

---

## Ringkasan: Perintah Apa di Jendela Mana

| Perintah | Jendela | Kapan |
|---|---|---|
| `code --install-extension ...` | CMD | Sekali, langkah 2 |
| `D:\Aplikasi\jdk17\bin\java -version` | CMD | Sekali, mengecek JDK |
| `sdkmanager --sdk_root=... "platform-tools" ...` | CMD | Sekali, langkah 6 |
| `sdkmanager --sdk_root=... --licenses` | CMD | Sekali, langkah 6 |
| `flutter --version` | CMD | Sekali, mengecek Flutter |
| `flutter config --android-sdk ...` | CMD | Sekali seumur hidup |
| `flutter config --jdk-dir ...` | CMD | Sekali seumur hidup |
| `flutter doctor --android-licenses` | CMD | Sekali |
| `flutter doctor -v` | CMD | Kapan saja, saat mengecek |
| `flutter devices` | CMD | Saat HP tidak terdeteksi |
| `setup_lokal.bat` | Klik dua kali di File Explorer | Sekali per folder proyek |
| `flutter run` | Terminal VS Code | Setiap kali mau coba |
| `flutter build apk --release` | Terminal VS Code | Saat mau membuat APK |

CMD boleh dibuka dari mana saja — perintah setup tidak peduli posisi foldernya. Terminal VS Code harus berada di folder proyek, dan itu otomatis kalau Anda membuka foldernya dulu di VS Code.

---

## Urutan Pemasangan yang Disarankan

1. Git for Windows — paling kecil, cepat
2. Visual Studio Code + ekstensinya
3. Pasang JDK 17 ke `D:\Aplikasi\jdk17` — lewat .msi dengan Custom Setup, atau ekstrak ZIP dari Microsoft
4. Ekstrak Flutter 3.22.3 ke `D:\Aplikasi\flutter`
5. Ekstrak Android cmdline-tools ke `D:\Aplikasi\android-sdk\cmdline-tools\latest`
6. Buat Environment Variable dan Path — **lalu tutup semua CMD dan VS Code**
7. CMD baru: `sdkmanager --sdk_root=... "platform-tools" "platforms;android-34" "build-tools;34.0.0"`
8. CMD: `flutter config --android-sdk ...` dan `flutter config --jdk-dir ...`
9. CMD: `flutter doctor --android-licenses`
10. CMD: `flutter doctor -v` — pastikan dua baris pertama hijau
11. HP: aktifkan USB Debugging, colok kabel, cek `flutter devices`
12. File Explorer: klik dua kali `setup_lokal.bat` di folder proyek
13. VS Code: buka folder proyek, tekan **F5**

Sekitar 1 jam, mayoritas hanya menunggu unduhan.
