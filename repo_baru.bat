@echo off
chcp 65001 >nul
setlocal

echo.
echo ============================================
echo   Siapkan Repo Baru di GitHub
echo ============================================
echo.
echo Script ini akan:
echo   1. Memasang build.yml versi terbaru otomatis
echo   2. Memulai riwayat Git dari nol
echo   3. Mengunggah semuanya ke repo baru Anda
echo.

REM ---- Cek Git --------------------------------------------------------
where git >nul 2>nul
if errorlevel 1 (
    echo [GAGAL] Git belum terpasang.
    echo Unduh di: https://git-scm.com/download/win
    echo.
    pause
    exit /b 1
)

REM ---- Pastikan dijalankan di folder proyek ----------------------------
if not exist pubspec.yaml (
    echo [GAGAL] File pubspec.yaml tidak ada di folder ini.
    echo Jalankan script ini DI DALAM folder proyek.
    echo Folder sekarang: %CD%
    echo.
    pause
    exit /b 1
)

if not exist ci\build.yml.txt (
    echo [GAGAL] File ci\build.yml.txt tidak ditemukan.
    echo Pastikan folder ci ikut tersalin ke folder proyek.
    echo.
    pause
    exit /b 1
)

echo [1/6] Memasang build.yml versi terbaru...
if not exist .github\workflows mkdir .github\workflows
copy /Y ci\build.yml.txt .github\workflows\build.yml >nul
if errorlevel 1 (
    echo [GAGAL] Tidak bisa menulis .github\workflows\build.yml
    pause
    exit /b 1
)
echo       Selesai. Tidak perlu edit manual lagi.
echo.

REM ---- Minta URL repo -------------------------------------------------
echo Buat dulu repo KOSONG di GitHub, misalnya:
echo   https://github.com/new  -^>  nama: kasir-laundry-2
echo Jangan centang "Add a README file".
echo.
echo Lalu salin URL-nya, contoh:
echo   https://github.com/anggac1/kasir-laundry-2.git
echo.
set /p REPO="Tempel URL repo di sini lalu Enter: "

if "%REPO%"=="" (
    echo [GAGAL] URL kosong.
    pause
    exit /b 1
)

echo.
echo Repo tujuan : %REPO%
echo Folder      : %CD%
echo.
echo PERINGATAN: riwayat Git lama di folder ini akan dihapus,
echo dan isi repo tujuan akan diganti seluruhnya.
echo Berkas kode Anda sendiri TIDAK ada yang hilang.
echo.
set /p LANJUT="Ketik Y lalu Enter untuk lanjut: "
if /I not "%LANJUT%"=="Y" (
    echo Dibatalkan.
    pause
    exit /b 0
)

echo.
echo [2/6] Menghapus riwayat Git lama...
if exist .git rmdir /s /q .git

echo [3/6] Memulai repositori baru...
git init

echo [4/6] Menambahkan berkas...
git add -A

echo [5/6] Membuat commit...
git -c user.email=kasir@lokal -c user.name=Kasir commit -m "Kasir Laundry - offline POS" --allow-empty

echo [6/6] Mengunggah ke GitHub...
git branch -M main
git remote add origin %REPO%
echo.
echo Kalau muncul jendela login, masuk dengan akun GitHub Anda.
echo.
git push -u origin main --force

if errorlevel 1 (
    echo.
    echo ============================================
    echo   GAGAL mengirim.
    echo.
    echo   Penyebab tersering:
    echo   - URL repo salah ketik
    echo   - Repo belum dibuat di GitHub
    echo   - Login GitHub dibatalkan
    echo.
    echo   Perbaiki lalu jalankan script ini lagi.
    echo ============================================
    pause
    exit /b 1
)

echo.
echo ============================================
echo   Berhasil.
echo.
echo   Buka repo Anda di GitHub, masuk tab Actions.
echo   Build berjalan otomatis, tunggu 5-10 menit.
echo   APK ada di bagian Artifacts.
echo ============================================
echo.
pause
