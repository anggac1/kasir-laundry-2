@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo.
echo ============================================
echo   Kasir Laundry - Setup dan Jalankan
echo ============================================
echo.
echo Yang akan dikerjakan script ini, berurutan:
echo.
echo   [1/4] Menyiapkan proyek       - sekali seumur folder
echo   [2/4] Mencari emulator        - beberapa detik
echo   [3/4] Menyalakan emulator     - 1-3 menit
echo   [4/4] Build dan jalankan      - 5-15 menit pertama kali
echo.
echo Kalau ada yang gagal, script BERHENTI dan menjelaskan
echo penyebabnya. Jendela ini tidak akan menutup sendiri.
echo.
echo --------------------------------------------
echo   Memeriksa perkakas dulu...
echo --------------------------------------------
echo.

REM ---- Pastikan dijalankan dari folder proyek ---------------------------
if not exist pubspec.yaml (
    echo [GAGAL] File pubspec.yaml tidak ada di folder ini.
    echo Folder sekarang: %CD%
    echo.
    echo Script ini harus berada di dalam folder kasir-laundry-source.
    echo.
    pause
    exit /b 1
)

REM ---- Cek Flutter -------------------------------------------------------
where flutter >nul 2>nul
if errorlevel 1 (
    echo [GAGAL] Flutter tidak ditemukan di PATH.
    echo.
    echo Buka SETUP_LOKAL.md, ulangi langkah 7b ^(Path^) lalu tutup-buka
    echo semua jendela CMD.
    echo.
    pause
    exit /b 1
)
echo [OK] Flutter ditemukan.

REM ======================================================================
REM   Mencari Android SDK
REM ======================================================================
set SDK=

REM --- Cara 1: baca dari pengaturan Flutter yang tersimpan ---------------
for /f "tokens=2*" %%A in ('flutter config --list ^| findstr /I "android-sdk:"') do set SDK=%%B
for /f "tokens=* delims= " %%A in ("!SDK!") do set SDK=%%A
if defined SDK if exist "!SDK!\emulator\emulator.exe" goto sdk_ketemu

REM --- Cara 2: coba lokasi-lokasi yang lazim ----------------------------
call :coba "%LOCALAPPDATA%\Android\Sdk"
if defined SDK goto sdk_ketemu
call :coba "D:\Aplikasi\andoidsdk"
if defined SDK goto sdk_ketemu
call :coba "D:\Aplikasi\androidsdk"
if defined SDK goto sdk_ketemu
call :coba "D:\Aplikasi\Android\Sdk"
if defined SDK goto sdk_ketemu
call :coba "C:\Android\Sdk"
if defined SDK goto sdk_ketemu

REM --- Cara 3: sisir setiap subfolder di D:\Aplikasi ---------------------
echo      Menyisir D:\Aplikasi untuk mencari SDK...
if exist "D:\Aplikasi" (
    for /d %%D in ("D:\Aplikasi\*") do (
        if not defined SDK (
            if exist "%%~fD\emulator\emulator.exe" set SDK=%%~fD
        )
    )
)
if defined SDK goto sdk_ketemu

REM --- Cara 4: menyerah, tanya langsung ke pengguna ----------------------
echo.
echo ============================================
echo   Android SDK belum ketemu otomatis.
echo ============================================
echo.
echo Buka Android Studio di jendela lain:
echo   File - Settings - Languages and Frameworks - Android SDK
echo Salin isi kotak "Android SDK Location" di bagian atas.
echo.
echo Lalu TEMPEL DI SINI ^(klik kanan untuk menempel^) dan tekan Enter.
echo Kosongkan lalu Enter untuk keluar.
echo.

:tanya_path
set SDK=
set /p SDK="Android SDK Location: "
if not defined SDK (
    echo Dibatalkan.
    pause
    exit /b 1
)
REM Buang tanda kutip kalau ikut tersalin
set SDK=!SDK:"=!
REM Buang garis miring di ujung kalau ada
if "!SDK:~-1!"=="\" set SDK=!SDK:~0,-1!

if not exist "!SDK!\emulator\emulator.exe" (
    echo.
    echo   Tidak ada emulator\emulator.exe di dalam:
    echo     !SDK!
    echo.
    if exist "!SDK!" (
        echo   Foldernya ada, tapi emulatornya belum dipasang.
        echo   Di Android Studio: Settings - Android SDK - tab SDK Tools
        echo   - centang "Android Emulator" - Apply - tunggu selesai.
        echo   Setelah itu tempel lagi path yang sama di bawah.
    ) else (
        echo   Foldernya sendiri tidak ada. Salah ketik atau salah salin.
    )
    echo.
    goto tanya_path
)

:sdk_ketemu
echo [OK] Android SDK: !SDK!
flutter config --android-sdk "!SDK!" >nul 2>nul

set EMULATOR_EXE=!SDK!\emulator\emulator.exe
set ADB_EXE=!SDK!\platform-tools\adb.exe

if not exist "!ADB_EXE!" (
    echo.
    echo [GAGAL] adb.exe tidak ada di !SDK!\platform-tools\
    echo.
    echo Di Android Studio: Settings - Android SDK - tab SDK Tools
    echo - centang "Android SDK Platform-Tools" - Apply.
    echo.
    pause
    exit /b 1
)

REM ======================================================================
REM   1. Setup proyek, sekali saja
REM ======================================================================
echo.
if not exist "android\app\src\main\AndroidManifest.xml" (
    echo [1/4] Menyiapkan proyek...
    if not exist "setup_lokal.bat" (
        echo [GAGAL] setup_lokal.bat tidak ada di folder ini.
        pause
        exit /b 1
    )
    call setup_lokal.bat
    if errorlevel 1 (
        echo [GAGAL] Penyiapan proyek gagal, lihat pesan di atas.
        pause
        exit /b 1
    )
) else (
    echo [1/4] Proyek sudah pernah disiapkan, dilewati.
)

REM ======================================================================
REM   2. Cari emulator yang sudah dibuat
REM ======================================================================
echo.
echo [2/4] Mencari daftar emulator...
set AVD=
for /f "delims=" %%A in ('"!EMULATOR_EXE!" -list-avds 2^>nul') do (
    if not defined AVD set AVD=%%A
)

if not defined AVD (
    echo.
    echo ============================================
    echo   Belum ada emulator yang dibuat.
    echo ============================================
    echo.
    echo Buka Android Studio, lalu:
    echo   1. Menu Tools - Device Manager
    echo   2. Klik tanda + atau "Create Virtual Device"
    echo   3. Pilih Pixel 4a - Next
    echo   4. Pilih baris API 34 ^(Android 14^) - JANGAN yang
    echo      bertuliskan Preview, beta, DEV, atau CANARY
    echo   5. Next - Finish, tunggu unduhannya selesai
    echo.
    echo Setelah emulatornya jadi, tutup Android Studio lalu
    echo klik dua kali jalankan.bat lagi.
    echo.
    pause
    exit /b 1
)
echo [OK] Emulator tersedia: !AVD!

REM ======================================================================
REM   3. Nyalakan emulator kalau belum menyala
REM ======================================================================
echo.
"!ADB_EXE!" devices 2>nul | findstr /I "emulator-" >nul
if not errorlevel 1 (
    echo [3/4] Emulator sudah menyala, dipakai yang itu.
    goto emulator_siap
)

echo [3/4] Menyalakan emulator "!AVD!"...
echo       Jendela emulator terbuka terpisah. Jangan ditutup.
start "" "!EMULATOR_EXE!" -avd "!AVD!"

echo       Menunggu perangkat terdeteksi...
"!ADB_EXE!" wait-for-device

echo       Menunggu Android selesai menyala ^(1-3 menit^)...
set /a COBA=0
:cek_boot
set /a COBA+=1
set BOOTED=
for /f "delims=" %%B in ('"!ADB_EXE!" shell getprop sys.boot_completed 2^>nul') do set BOOTED=%%B
if "!BOOTED!"=="1" goto emulator_siap
if !COBA! GEQ 60 (
    echo.
    echo [GAGAL] Emulator belum selesai menyala setelah 3 menit.
    echo.
    echo Lihat jendela emulatornya. Kalau layarnya hitam atau macet,
    echo tutup jendela emulator itu lalu jalankan script ini lagi.
    echo.
    pause
    exit /b 1
)
timeout /t 3 /nobreak >nul
goto cek_boot

:emulator_siap
echo [OK] Emulator siap.

REM ======================================================================
REM   4. Jalankan aplikasi
REM ======================================================================
echo.
echo ============================================
echo   Semua siap. Ringkasan:
echo ============================================
echo   Android SDK : !SDK!
echo   Emulator    : !AVD!
echo   Proyek      : %CD%
echo ============================================
echo.
echo [4/4] Berikutnya: build dan menjalankan aplikasi.
echo.
echo       Build PERTAMA kali makan 5-15 menit karena Gradle
echo       mengunduh sekitar 1 GB. Jangan dibatalkan di tengah,
echo       cache yang rusak harus diunduh ulang dari nol.
echo.
echo       Build berikutnya jauh lebih cepat, di bawah 1 menit.
echo.
echo       Setelah aplikasi muncul di emulator, jendela ini
echo       TETAP DIPAKAI untuk hot reload. Jangan ditutup.
echo.
pause
echo.
echo --------------------------------------------
echo   Membangun aplikasi, mohon tunggu...
echo --------------------------------------------
echo.
flutter run

if errorlevel 1 (
    echo.
    echo ============================================
    echo   Build atau run gagal.
    echo ============================================
    echo.
    echo Baca baris merah di atas. Yang sering terjadi:
    echo   - Koneksi putus saat Gradle mengunduh, jalankan ulang saja
    echo   - Cache rusak, hapus folder "build" lalu ulangi
    echo   - Ada kesalahan di kode, kirimkan pesan errornya ke saya
    echo.
    pause
    exit /b 1
)

echo.
echo ============================================
echo   Aplikasi sudah berhenti.
echo ============================================
echo.
echo Kalau tadi Anda menekan 'q', itu memang cara berhentinya.
echo.
echo Untuk menjalankan lagi: klik dua kali jalankan.bat.
echo Kali ini jauh lebih cepat, emulator dan cache sudah siap.
echo.
echo Pengingat tombol saat aplikasi sedang berjalan:
echo   r  = hot reload, perubahan kode langsung muncul di emulator
echo   R  = restart penuh aplikasi
echo   q  = berhenti
echo.
echo Alur kerja sehari-hari:
echo   1. Jalankan script ini, biarkan jendelanya terbuka
echo   2. Ubah kode di VS Code, simpan dengan Ctrl+S
echo   3. Kembali ke jendela ini, tekan r
echo   4. Kalau sudah puas, klik dua kali push_ke_github.bat
echo      untuk membuat APK asli lewat GitHub Actions
echo.
echo ============================================
echo.
pause
exit /b 0

REM ======================================================================
REM   Sub-rutin: cek satu lokasi kandidat
REM ======================================================================
:coba
if exist "%~1\emulator\emulator.exe" set SDK=%~1
exit /b 0
