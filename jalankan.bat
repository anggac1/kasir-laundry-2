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
echo   [1/4] Menyiapkan proyek    - Otomatis (Fokus di jendela/terminal ini)
echo   [2/4] Mencari emulator     - Otomatis (Jika gagal, butuh Android Studio)
echo   [3/4] Menyalakan emulator  - Akan muncul jendela Emulator baru
echo   [4/4] Build dan jalankan   - Coding di VS Code, lihat hasil di Emulator
echo.
echo Kalau ada yang gagal, script BERHENTI dan menjelaskan
echo penyebabnya. Jendela ini tidak akan menutup sendiri.
echo.

REM ---- Pastikan jendelanya bisa menerima ketikan ------------------------
choice /c YN /n /t 15 /d Y /m "Tekan Y untuk mulai, N untuk batal [Y]: " >nul 2>nul
if errorlevel 255 goto salah_jendela
if errorlevel 2 (
    echo.
    echo Dibatalkan oleh pengguna.
    goto keluar
)
goto jendela_ok

:salah_jendela
echo.
echo ============================================
echo   Jendela ini tidak bisa menerima ketikan
echo ============================================
echo.
echo Script akan berhenti sendiri saat menunggu jawaban Anda.
echo Biasanya ini terjadi kalau dijalankan lewat Code Runner,
echo yang menampilkan hasilnya di panel Output VS Code.
echo.
echo PAKAI SALAH SATU CARA INI:
echo.
echo   A. File Explorer
echo       Buka folder ini, lalu klik dua kali jalankan.bat
echo       %CD%
echo.
echo   B. Terminal VS Code
echo       Tekan Ctrl dan tombol backtick, lalu ketik:
echo       .\jalankan.bat
echo.
goto keluar

:jendela_ok
echo.
echo --------------------------------------------
echo   Memeriksa perkakas dulu... (Fokus: Terminal ini)
echo --------------------------------------------
echo.

REM ---- Pastikan dijalankan dari folder proyek ---------------------------
if not exist pubspec.yaml (
    echo [GAGAL] File pubspec.yaml tidak ada di folder ini.
    echo Folder sekarang: %CD%
    echo.
    echo Script ini harus berada di dalam folder kasir-laundry-source.
    echo.
    goto keluar
)

REM ---- Cek Flutter -------------------------------------------------------
where flutter >nul 2>nul
if errorlevel 1 (
    echo [GAGAL] Flutter tidak ditemukan di PATH.
    echo.
    echo Buka SETUP_LOKAL.md, ulangi langkah 7b ^(Path^) lalu tutup-buka
    echo semua jendela CMD.
    echo.
    goto keluar
)
echo [OK] 1. Flutter ditemukan.

REM ======================================================================
REM   Mencari Android SDK
REM ======================================================================
set SDK=

for /f "tokens=2*" %%A in ('flutter config --list ^| findstr /I "android-sdk:"') do set SDK=%%B
for /f "tokens=* delims= " %%A in ("!SDK!") do set SDK=%%A
if defined SDK if exist "!SDK!\emulator\emulator.exe" goto sdk_ketemu

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

echo       Menyisir D:\Aplikasi untuk mencari SDK...
if exist "D:\Aplikasi" (
    for /d %%D in ("D:\Aplikasi\*") do (
        if not defined SDK (
            if exist "%%~fD\emulator\emulator.exe" set SDK=%%~fD
        )
    )
)
if defined SDK goto sdk_ketemu

echo.
echo ============================================
echo   Android SDK belum ketemu otomatis.
echo ============================================
echo.
echo INFO JENDELA: Silakan buka "Android Studio" sekarang.
echo   Pilih menu: File - Settings - Languages and Frameworks - Android SDK
echo   Salin isi kotak "Android SDK Location" di bagian atas.
echo.
echo Lalu KEMBALI KE TERMINAL INI, TEMPEL DI SINI ^(klik kanan^) dan tekan Enter.
echo Kosongkan lalu Enter untuk keluar.
echo.

:tanya_path
set SDK=
set /p SDK="Android SDK Location: "
if not defined SDK (
    echo Dibatalkan.
    goto keluar
)
set SDK=!SDK:"=!
if "!SDK:~-1!"=="\" set SDK=!SDK:~0,-1!

if not exist "!SDK!\emulator\emulator.exe" (
    echo.
    echo   Tidak ada emulator\emulator.exe di dalam:
    echo     !SDK!
    echo.
    if exist "!SDK!" (
        echo   INFO: Foldernya ada, tapi emulatornya belum dipasang.
        echo   Fokus ke Android Studio: Settings - Android SDK - tab SDK Tools
        echo   - centang "Android Emulator" - Apply - tunggu selesai.
    ) else (
        echo   Foldernya sendiri tidak ada. Salah ketik atau salah salin.
    )
    echo.
    goto tanya_path
)

:sdk_ketemu
echo [OK] 2. Android SDK: !SDK!

call flutter config --android-sdk "!SDK!" >nul 2>nul

set EMULATOR_EXE=!SDK!\emulator\emulator.exe
set ADB_EXE=!SDK!\platform-tools\adb.exe

if not exist "!ADB_EXE!" (
    echo.
    echo [GAGAL] adb.exe tidak ada di !SDK!\platform-tools\
    echo.
    echo INFO JENDELA: Buka "Android Studio"
    echo Ke menu: Settings - Android SDK - tab SDK Tools
    echo - centang "Android SDK Platform-Tools" - Apply.
    echo.
    goto keluar
)

REM ======================================================================
REM   1. Setup proyek
REM ======================================================================
echo.
echo [1/4] Menyiapkan proyek... ^(Fokus: Biarkan terminal ini bekerja otomatis^)
if not exist "android\app\src\main\AndroidManifest.xml" (
    if not exist "setup_lokal.bat" (
        echo [GAGAL] setup_lokal.bat tidak ada di folder ini.
        goto keluar
    )
    cmd /c setup_lokal.bat
    if errorlevel 1 (
        echo [GAGAL] Penyiapan proyek gagal, lihat pesan di atas.
        goto keluar
    )
) else (
    echo       - Proyek sudah pernah disiapkan, dilewati.
)

REM ======================================================================
REM   2. Cari emulator
REM ======================================================================
echo.
echo [2/4] Mencari daftar emulator... ^(Fokus: Terminal ini, mengecek di latar belakang^)
set AVD=
for /f "delims=" %%A in ('""!EMULATOR_EXE!" -list-avds 2^>nul"') do (
    if not defined AVD set AVD=%%A
)

if not defined AVD (
    echo.
    echo ============================================
    echo   Belum ada emulator yang dibuat.
    echo ============================================
    echo.
    echo INFO JENDELA: Buka "Android Studio" sekarang, lalu:
    echo   1. Menu Tools - Device Manager
    echo   2. Klik tanda + atau "Create Virtual Device"
    echo   3. Pilih Pixel 4a - Next
    echo   4. Pilih baris API 34 ^(Android 14^) - JANGAN yang bertuliskan Preview/beta
    echo   5. Next - Finish, tunggu unduhannya selesai
    echo.
    echo Setelah selesai, Anda bisa tutup Android Studio, lalu jalankan script ini lagi.
    goto keluar
)
echo [OK] Emulator tersedia: !AVD!

REM ======================================================================
REM   3. Nyalakan emulator
REM ======================================================================
echo.
"!ADB_EXE!" devices 2>nul | findstr /I "emulator-" >nul
if not errorlevel 1 (
    echo [3/4] Emulator sudah menyala di latar belakang, dilanjutkan.
    goto emulator_siap
)

echo [3/4] Menyalakan emulator "!AVD!"...
echo        INFO JENDELA: Sebuah layar HP ^(Emulator^) baru akan muncul.
echo        Silakan geser jendela Emulator tersebut agar tidak menutupi VS Code Anda.
echo        Jangan tutup jendela emulatornya selama Anda sedang coding.

REM Menghapus log lama dengan perintah >nul 2>&1 agar tidak muncul pesan error meskipun file terkunci
if exist "%TEMP%\emu_error.log" del "%TEMP%\emu_error.log" >nul 2>&1
start /B "" cmd /c ""!EMULATOR_EXE!" -avd "!AVD!" > "%TEMP%\emu_error.log" 2>&1"

echo        Menunggu Emulator terdeteksi oleh terminal ini...
set /a COBADETEKSI=0

:cek_deteksi
set /a COBADETEKSI+=1
echo        - Cek sambungan ke-!COBADETEKSI! / 10 ...
"!ADB_EXE!" devices 2>nul | findstr /I "emulator-" >nul
if not errorlevel 1 goto deteksi_sukses

if !COBADETEKSI! GEQ 10 (
    echo.
    echo ============================================
    echo [GAGAL] Emulator tidak terdeteksi setelah 30 detik.
    echo ============================================
    echo.
    echo INFO JENDELA: Fokus ke terminal ini.
    echo Berikut output sistem untuk mencari tahu kerusakannya:
    echo.
    echo --- [ STATUS KONEKSI ADB ] ---
    "!ADB_EXE!" devices
    echo.
    echo --- [ LOG ERROR EMULATOR ] ---
    if exist "%TEMP%\emu_error.log" (
        type "%TEMP%\emu_error.log"
    ) else (
        echo ^(Log emulator kosong.^)
    )
    echo --------------------------------------------
    goto keluar
)
timeout /t 3 /nobreak >nul
goto cek_deteksi

:deteksi_sukses
echo [OK] Emulator terdeteksi.
echo        INFO JENDELA: Lihat ke layar Emulator. Menunggu Android selesai loading...
set /a COBA=0

:cek_boot
set /a COBA+=1
echo        - Loading ke-!COBA! / 30 ...
set BOOTED=
for /f "delims=" %%B in ('"!ADB_EXE!" shell getprop sys.boot_completed 2^>nul') do set BOOTED=%%B
if "!BOOTED!"=="1" goto emulator_siap
if !COBA! GEQ 30 (
    echo.
    echo ============================================
    echo [GAGAL] Emulator macet saat booting ^(lebih dari 90 detik^).
    echo ============================================
    echo.
    echo Tutup paksa jendela emulatornya ^(X merah^). Lalu buka Android Studio 
    echo Device Manager, klik titik tiga di emulator, pilih "Wipe Data", lalu ulangi.
    goto keluar
)
timeout /t 3 /nobreak >nul
goto cek_boot

:emulator_siap
echo.
echo ==================================================================
echo [OK] LAYAR HP EMULATOR SUDAH SIAP! 
echo ==================================================================

REM ======================================================================
REM   4. Jalankan aplikasi
REM ======================================================================
echo.
echo [4/4] Tahap Akhir: Build dan jalankan aplikasi.
echo.
echo INFO JENDELA: 
echo - Terminal akan OTOMATIS melakukan proses build sekarang.
echo - Biarkan terminal ini bekerja sampai aplikasi Kasir terbuka di Emulator.
echo.
echo Melanjutkan dalam 3 detik...
timeout /t 3 /nobreak >nul

echo.
echo --------------------------------------------
echo   Membangun aplikasi, mohon tunggu...
echo --------------------------------------------
echo.
echo ==================================================================
echo   STATUS SAAT INI: MENGUNDUH / BUILD APLIKASI
echo ==================================================================
echo.
echo   Jika muncul tulisan "Running Gradle task 'assembleDebug'..."
echo   dengan simbol berputar ^(/ \ - ^|^), internet Anda sedang 
echo   mendownload sistem. Flutter memang menyembunyikan persentasenya.
echo.
echo   Mohon bersabar, ini memakan waktu 5-15 menit pertama kali.
echo   Jika koneksi terputus/error, teks merah akan muncul.
echo ==================================================================
echo.

call flutter run

if errorlevel 1 (
    echo.
    echo ============================================
    echo   [GAGAL] Build atau run aplikasi gagal.
    echo ============================================
    echo.
    echo INFO JENDELA: Fokus ke teks error warna merah di terminal bagian atas.
    goto keluar
)

echo.
echo ============================================
echo   Aplikasi sudah berhenti berjalan.
echo ============================================
echo.
goto keluar

REM ======================================================================
REM   Sub-rutin dan Label Keluar
REM ======================================================================

:coba
if exist "%~1\emulator\emulator.exe" set SDK=%~1
exit /b 0

:keluar
echo.
echo --------------------------------------------
echo Script telah selesai atau terhenti.
echo INFO JENDELA: Tekan sembarang tombol di keyboard Anda untuk keluar dari terminal ini...
pause >nul
exit /b 0