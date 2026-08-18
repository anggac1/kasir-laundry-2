@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo.
echo ============================================
echo   Setup Proyek Lokal - Kasir Laundry
echo ============================================
echo.

REM ---- 1. Pastikan Flutter ada ----------------------------------------
where flutter >nul 2>nul
if errorlevel 1 (
    echo [GAGAL] Perintah "flutter" tidak ditemukan.
    echo.
    echo Pastikan Flutter sudah dipasang dan foldernya sudah
    echo dimasukkan ke Environment Variable PATH.
    echo Baca SETUP_LOKAL.md bagian "Menambahkan Flutter ke PATH".
    echo.
    pause
    exit /b 1
)

echo [1/5] Flutter ditemukan.
call flutter --version
echo.

REM ---- 2. Buat kerangka Android ---------------------------------------
if exist android (
    echo [2/5] Folder android sudah ada, langkah ini dilewati.
) else (
    echo [2/5] Membuat kerangka Android...
    copy /Y pubspec.yaml pubspec.yaml.bak >nul
    call flutter create . --project-name laundry_pos --org id.laundry --platforms=android
    move /Y pubspec.yaml.bak pubspec.yaml >nul
    if exist test rmdir /S /Q test
)
echo.

REM ---- 3. Pasang AndroidManifest milik kita ----------------------------
echo [3/5] Memasang AndroidManifest ^(izin Bluetooth, tanpa izin INTERNET^)...
copy /Y android_overrides\AndroidManifest.xml android\app\src\main\AndroidManifest.xml >nul
if errorlevel 1 (
    echo [GAGAL] Tidak bisa menyalin AndroidManifest.xml
    pause
    exit /b 1
)
echo.

REM ---- 4. Tambal namespace plugin lama ---------------------------------
echo [4/5] Menambal namespace plugin...
findstr /C:"project.android.namespace" android\build.gradle >nul 2>nul
if errorlevel 1 (
    type android_overrides\namespace_patch.gradle >> android\build.gradle
    echo       Tambalan ditambahkan.
) else (
    echo       Tambalan sudah ada, dilewati.
)
echo.

REM ---- 5. Ambil dependensi --------------------------------------------
echo [5/5] Mengambil dependensi...
call flutter pub get
echo.

echo ============================================
echo   Selesai.
echo.
echo   Sambungkan HP lewat kabel USB dengan
echo   USB Debugging aktif, lalu jalankan:
echo.
echo       flutter devices
echo       flutter run
echo.
echo   Untuk membuat APK langsung:
echo.
echo       flutter build apk --release
echo.
echo   Hasilnya ada di:
echo   build\app\outputs\flutter-apk\app-release.apk
echo ============================================
echo.
pause
