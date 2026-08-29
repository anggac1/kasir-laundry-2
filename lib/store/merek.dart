import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Identitas aplikasi: nama dan logo diambil dari berkas di assets/merek/.
//
// Aturannya sengaja dibuat sesederhana mungkin: taruh SATU berkas gambar di
// folder itu, dan nama berkasnya jadi nama aplikasi. "Kasir Melati.png"
// membuat aplikasi bernama Kasir Melati dengan gambar itu sebagai logo.
// Folder kosong berarti pakai bawaan: logo Flutter dan nama "Kasir Laundry".
class Merek {
  static final Merek instance = Merek._();
  Merek._();

  static const String namaBawaan = 'Kasir Laundry';
  static const _ekstensi = ['.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp'];

  String _nama = namaBawaan;
  String? _logo;

  String get nama => _nama;

  // #Path aset logo, null berarti belum ada berkas di assets/merek/
  String? get logo => _logo;

  // #Dibaca sekali saat aplikasi start, sebelum tampilan pertama digambar
  Future<void> muat() async {
    try {
      // AssetManifest.loadFromAssetBundle, bukan AssetManifest.json:
      // berkas json itu sudah tidak dibuat lagi sejak Flutter 3.16.
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final berkas = manifest
          .listAssets()
          .where((a) => a.startsWith('assets/merek/') && _gambar(a))
          .toList()
        ..sort();
      if (berkas.isEmpty) return;
      _logo = berkas.first;
      _nama = _tanpaEkstensi(berkas.first);
    } catch (_) {
      // Aset rusak atau tidak terbaca bukan alasan aplikasi gagal dibuka.
    }
  }

  // #Cek ekstensi berkas, huruf besar-kecil diabaikan
  static bool _gambar(String path) {
    final p = path.toLowerCase();
    return _ekstensi.any(p.endsWith);
  }

  // #"assets/merek/Kasir Melati.png" menjadi "Kasir Melati"
  static String _tanpaEkstensi(String path) {
    // Spasi pada nama berkas bisa tersimpan sebagai %20 di manifest.
    var n = Uri.decodeFull(path).split('/').last;
    final titik = n.lastIndexOf('.');
    if (titik > 0) n = n.substring(0, titik);
    return n.trim().isEmpty ? namaBawaan : n.trim();
  }
}

// Logo aplikasi berukuran [ukuran], jatuh ke logo Flutter bila belum diisi.
class LogoMerek extends StatelessWidget {
  final double ukuran;

  const LogoMerek({this.ukuran = 28, super.key});

  @override
  Widget build(BuildContext context) {
    final path = Merek.instance.logo;
    if (path == null) return FlutterLogo(size: ukuran);
    return Image.asset(
      path,
      width: ukuran,
      height: ukuran,
      fit: BoxFit.contain,
      // Berkas rusak atau format tidak didukung tidak boleh membuat
      // seluruh AppBar gagal digambar.
      errorBuilder: (_, __, ___) => FlutterLogo(size: ukuran),
    );
  }
}
