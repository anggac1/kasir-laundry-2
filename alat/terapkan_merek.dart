// Menerapkan logo dan nama dari assets/merek/ ke kerangka Android.
//
// Logikanya sederhana: ada berkas gambar di assets/merek/ atau tidak.
//   ada    -> nama berkas jadi nama di bawah ikon, gambarnya jadi ikon
//   kosong -> tidak mengubah apa pun, Flutter memakai bawaannya
//
// Dijalankan otomatis oleh setup_lokal.bat dan GitHub Actions setiap kali
// folder android/ dibuat ulang, jadi tidak ada langkah manual.
//
//   dart run alat/terapkan_merek.dart

import 'dart:io';

import 'package:image/image.dart';

// Ukuran ikon Android menurut kerapatan layar.
const _mipmap = {
  'mdpi': 48,
  'hdpi': 72,
  'xhdpi': 96,
  'xxhdpi': 144,
  'xxxhdpi': 192,
};

const _ekstensi = ['.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp'];

void main() {
  final folder = Directory('assets/merek');
  if (!folder.existsSync()) {
    print('  assets/merek/ tidak ada, memakai logo dan nama bawaan.');
    return;
  }

  // Ambil berkas gambar pertama secara alfabet. Berkas lain, termasuk
  // BACA_INI.txt, diabaikan.
  final gambar = folder
      .listSync()
      .whereType<File>()
      .where((f) => _ekstensi.any(f.path.toLowerCase().endsWith))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  if (gambar.isEmpty) {
    print('  assets/merek/ kosong, memakai logo dan nama bawaan.');
    return;
  }

  final berkas = gambar.first;
  final nama = _namaTanpaEkstensi(berkas.path);
  print('  Merek terbaca: "$nama" dari ${berkas.path}');

  _pasangNama(nama);
  _pasangIkon(berkas);
}

// #"assets/merek/Kasir Melati.png" menjadi "Kasir Melati"
String _namaTanpaEkstensi(String path) {
  var n = path.replaceAll('\\', '/').split('/').last;
  final titik = n.lastIndexOf('.');
  if (titik > 0) n = n.substring(0, titik);
  return n.trim();
}

// #Mengganti android:label di AndroidManifest yang sudah disalin
void _pasangNama(String nama) {
  final f = File('android/app/src/main/AndroidManifest.xml');
  if (!f.existsSync()) {
    print('  ! AndroidManifest belum ada, nama dilewati.');
    return;
  }
  final isi = f.readAsStringSync();
  // Karakter yang punya arti khusus di XML harus dilindungi, kalau tidak
  // nama seperti "Cuci & Setrika" membuat manifestnya gagal dibaca.
  final aman = nama
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
  final baru =
      isi.replaceAll(RegExp(r'android:label="[^"]*"'), 'android:label="$aman"');
  if (baru == isi) {
    print('  ! android:label tidak ditemukan, nama dilewati.');
    return;
  }
  f.writeAsStringSync(baru);
  print('  Nama di bawah ikon  -> $nama');
}

// #Membuat ic_launcher.png lima ukuran dari satu gambar sumber
void _pasangIkon(File sumber) {
  final asli = decodeImage(sumber.readAsBytesSync());
  if (asli == null) {
    print('  ! ${sumber.path} tidak terbaca sebagai gambar, ikon dilewati.');
    return;
  }
  var dibuat = 0;
  for (final e in _mipmap.entries) {
    final dir = Directory('android/app/src/main/res/mipmap-${e.key}');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final kecil = copyResize(asli,
        width: e.value, height: e.value, interpolation: Interpolation.average);
    File('${dir.path}/ic_launcher.png').writeAsBytesSync(encodePng(kecil));
    dibuat++;
  }
  print('  Ikon peluncur       -> $dibuat ukuran dibuat ulang');
}
