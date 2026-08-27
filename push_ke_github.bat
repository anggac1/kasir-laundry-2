@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo.
echo ============================================
echo   Unggah ke GitHub
echo ============================================
echo.
echo Yang dikerjakan script ini:
echo.
echo   1. Memperbarui build.yml dari ci\build.yml.txt
echo   2. Mengunggah kode ke repo GitHub Anda
echo   3. GitHub Actions membangun APK otomatis
echo.
echo Berkas .bat, folder _to_delete, dan panduan .md
echo selain README tidak ikut terunggah.
echo.

REM ---- Cek Git ----------------------------------------------------------
where git >nul 2>nul
if errorlevel 1 (
    echo [GAGAL] Git belum terpasang di laptop ini.
    echo.
    echo Unduh di: https://git-scm.com/download/win
    echo Pasang dengan opsi bawaan, lalu jalankan script ini lagi.
    echo.
    pause
    exit /b 1
)

REM ---- Pastikan di folder proyek ----------------------------------------
if not exist pubspec.yaml (
    echo [GAGAL] pubspec.yaml tidak ada di folder ini.
    echo Folder sekarang: %CD%
    echo.
    echo Script ini harus berada di dalam folder proyek.
    echo.
    pause
    exit /b 1
)

REM ---- Perbarui workflow dari sumbernya ----------------------------------
REM Selalu disalin ulang supaya versinya tidak pernah tertinggal.
if not exist ci\build.yml.txt (
    echo [GAGAL] ci\build.yml.txt tidak ditemukan.
    echo Tanpa berkas itu GitHub Actions tidak tahu cara membangun APK.
    echo.
    pause
    exit /b 1
)
if not exist .github\workflows mkdir .github\workflows
copy /Y ci\build.yml.txt .github\workflows\build.yml >nul
echo [OK] build.yml diperbarui dari ci\build.yml.txt

REM ---- Ingat URL repo dari unggahan sebelumnya ---------------------------
set REPO=
if exist .git (
    for /f "delims=" %%U in ('git remote get-url origin 2^>nul') do set REPO=%%U
)

echo.
if defined REPO (
    echo Repo tersimpan: !REPO!
    echo.
    set /p GANTI="Tekan Enter untuk memakai repo itu, atau ketik G lalu Enter untuk ganti: "
    if /I "!GANTI!"=="G" set REPO=
)

if not defined REPO (
    echo.
    echo Buka repo GitHub Anda, klik tombol hijau "Code",
    echo salin URL HTTPS-nya.
    echo.
    echo Untuk menempel di jendela ini, KLIK KANAN. Ctrl+V
    echo sering tidak berfungsi di CMD.
    echo.
    set /p REPO="Tempel URL repo lalu Enter: "
)

if not defined REPO (
    echo [GAGAL] URL kosong, dibatalkan.
    pause
    exit /b 1
)
set REPO=!REPO:"=!

echo.
echo --------------------------------------------
echo   Repo tujuan : !REPO!
echo   Folder      : %CD%
echo --------------------------------------------
echo.
echo PERINGATAN: seluruh isi repo di GitHub akan DIGANTI
echo dengan isi folder ini.
echo.
set /p LANJUT="Ketik Y lalu Enter untuk lanjut: "
if /I not "!LANJUT!"=="Y" (
    echo Dibatalkan.
    pause
    exit /b 0
)

echo.
echo [1/5] Menyiapkan repositori lokal...
if not exist .git git init

echo [2/5] Menambahkan berkas...
REM -A ikut mencatat berkas yang dihapus, supaya repo tidak menyimpan
REM sisa berkas lama yang sudah tidak ada di folder ini.
git add -A

echo [3/5] Membuat commit...
git -c user.email=kasir@lokal -c user.name=Kasir commit -m "Kasir Laundry" --allow-empty

echo [4/5] Mengatur remote...
git branch -M main
git remote remove origin >nul 2>nul
git remote add origin "!REPO!"

echo [5/5] Mengirim ke GitHub...
echo.
echo Kalau muncul jendela login, masuk dengan akun GitHub Anda.
echo.
git push -u origin main --force

if errorlevel 1 (
    echo.
    echo ============================================
    echo   GAGAL mengirim.
    echo ============================================
    echo.
    echo Penyebab tersering:
    echo   - URL repo salah ketik
    echo   - Login GitHub dibatalkan atau salah
    echo   - Repo belum dibuat di GitHub
    echo.
    echo Jalankan script ini lagi, ketik G saat ditanya
    echo untuk memasukkan URL yang benar.
    echo.
    pause
    exit /b 1
)

echo.
echo ============================================
echo   Berhasil dikirim.
echo ============================================
echo.
echo Langkah berikutnya:
echo   1. Buka repo Anda di GitHub
echo   2. Masuk tab Actions
echo   3. Tunggu 5-10 menit sampai muncul centang hijau
echo   4. Buka build yang selesai, gulir ke Artifacts
echo   5. Unduh kasir-laundry-apk, ekstrak ZIP-nya
echo.
echo Copot dulu aplikasi lama di HP sebelum memasang
echo yang baru. Data nota akan ikut terhapus.
echo.
pause
