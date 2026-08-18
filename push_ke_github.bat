@echo off
chcp 65001 >nul
setlocal

echo.
echo ============================================
echo   Unggah Proyek ke GitHub
echo ============================================
echo.
echo Script ini mengunggah proyek dengan struktur folder
echo yang UTUH. Unggah lewat web sering meratakan folder
echo dan membuat build gagal.
echo.

REM ---- Cek Git --------------------------------------------------------
where git >nul 2>nul
if errorlevel 1 (
    echo [GAGAL] Git belum terpasang di laptop ini.
    echo.
    echo Unduh dulu di: https://git-scm.com/download/win
    echo Pasang dengan opsi bawaan, lalu jalankan script ini lagi.
    echo.
    pause
    exit /b 1
)

REM ---- Pastikan dijalankan di folder yang benar -------------------------
if not exist pubspec.yaml (
    echo [GAGAL] File pubspec.yaml tidak ada di folder ini.
    echo.
    echo Script ini harus dijalankan DI DALAM folder proyek
    echo hasil ekstrak ZIP, yaitu folder yang berisi:
    echo   pubspec.yaml, lib\, .github\, android_overrides\
    echo.
    echo Folder sekarang: %CD%
    echo.
    pause
    exit /b 1
)

REM Selalu perbarui workflow dari ci\build.yml.txt, supaya versinya
REM tidak pernah tertinggal tanpa Anda sadari.
if exist ci\build.yml.txt (
    if not exist .github\workflows mkdir .github\workflows
    copy /Y ci\build.yml.txt .github\workflows\build.yml >nul
    echo [OK] build.yml diperbarui dari ci\build.yml.txt
)

if not exist .github\workflows\build.yml (
    echo [GAGAL] File .github\workflows\build.yml tidak ditemukan.
    echo Ekstrak ulang ZIP-nya, folder .github mungkin tidak ikut.
    echo.
    pause
    exit /b 1
)

echo [OK] Struktur folder benar.
echo.

REM ---- Minta URL repo -------------------------------------------------
echo Buka repo GitHub Anda, klik tombol hijau "Code",
echo salin URL HTTPS-nya.
echo.
set /p REPO="Tempel URL repo di sini lalu tekan Enter: "

if "%REPO%"=="" (
    echo [GAGAL] URL kosong.
    pause
    exit /b 1
)

echo.
echo Repo tujuan : %REPO%
echo Folder      : %CD%
echo.
echo PERINGATAN: seluruh isi repo di GitHub akan DIGANTI
echo dengan isi folder ini.
echo.
set /p LANJUT="Ketik Y lalu Enter untuk lanjut: "
if /I not "%LANJUT%"=="Y" (
    echo Dibatalkan.
    pause
    exit /b 0
)

echo.
echo [1/5] Menyiapkan repositori lokal...
if not exist .git git init

echo [2/5] Menambahkan berkas...
git add -A

echo [3/5] Membuat commit...
git -c user.email=kasir@lokal -c user.name=Kasir commit -m "Kasir Laundry - offline POS" --allow-empty

echo [4/5] Mengatur remote...
git branch -M main
git remote remove origin >nul 2>nul
git remote add origin %REPO%

echo [5/5] Mengirim ke GitHub...
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
    echo   - Login GitHub dibatalkan
    echo   - Repo belum dibuat di GitHub
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
echo ============================================
echo.
pause
