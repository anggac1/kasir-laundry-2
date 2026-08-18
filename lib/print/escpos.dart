import 'receipt.dart';

/// Penyusun byte ESC/POS untuk printer thermal.
/// Ditulis sendiri (tanpa paket tambahan) supaya dependensi build minimal
/// dan perilakunya bisa dipastikan.
class EscPos {
  final List<int> _b = [];

  // Perintah dasar ESC/POS
  static const _esc = 0x1B;
  static const _gs = 0x1D;

  void init({bool fontKecil = false}) {
    _b.addAll([_esc, 0x40]); // ESC @  : reset printer
    _b.addAll([_esc, 0x74, 0x00]); // ESC t 0 : code page PC437
    _b.addAll([_esc, 0x52, 0x00]); // ESC R 0 : charset USA
    // ESC M n : 0 = Font A (12x24, 32 kolom), 1 = Font B (9x17, 42 kolom)
    _b.addAll([_esc, 0x4D, fontKecil ? 0x01 : 0x00]);
  }

  void rata(int n) => _b.addAll([_esc, 0x61, n.clamp(0, 2)]);

  void tebal(bool on) => _b.addAll([_esc, 0x45, on ? 1 : 0]);

  /// Perbesar huruf jadi dua kali lebar dan dua kali tinggi.
  ///
  /// Dikirim DUA perintah sekaligus, karena printer murah tidak seragam:
  ///   GS  ! n  -> standar, dipakai mayoritas printer
  ///   ESC ! n  -> dipahami sebagian printer lama yang mengabaikan GS !
  ///
  /// Bit ukuran pada ESC ! : 0x10 tinggi dobel, 0x20 lebar dobel.
  /// Bit tebal pada ESC ! sengaja TIDAK dipakai, supaya tidak bentrok
  /// dengan ESC E yang mengurus tebal secara terpisah.
  void besar(bool on) {
    _b.addAll([_gs, 0x21, on ? 0x11 : 0x00]);
    _b.addAll([_esc, 0x21, on ? 0x30 : 0x00]);
  }

  void teks(String s) {
    _b.addAll(_encode(s));
    _b.add(0x0A);
  }

  void baris(int n) {
    for (var i = 0; i < n; i++) {
      _b.add(0x0A);
    }
  }

  void potong() {
    baris(3);
    _b.addAll([_gs, 0x56, 0x00]); // GS V 0 : full cut
  }

  List<int> selesai() => List<int>.unmodifiable(_b);

  /// Printer thermal umumnya tidak paham UTF-8.
  /// Huruf beraksen diturunkan ke ASCII, sisanya diganti '?'.
  static List<int> _encode(String s) {
    const map = {
      'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
      'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
      'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
      'ñ': 'n', 'ç': 'c',
      'Á': 'A', 'À': 'A', 'Â': 'A', 'Ä': 'A',
      'É': 'E', 'È': 'E', 'Ê': 'E', 'Ë': 'E',
      'Í': 'I', 'Ó': 'O', 'Ö': 'O', 'Ú': 'U', 'Ü': 'U',
      'Ñ': 'N', 'Ç': 'C',
      '“': '"', '”': '"', '‘': "'", '’': "'",
      '–': '-', '—': '-', '…': '...', ' ': ' ',
      'Rp': 'Rp',
    };
    final out = <int>[];
    for (final ch in s.split('')) {
      final g = map[ch] ?? ch;
      for (final c in g.runes) {
        out.add(c < 128 ? c : 0x3F); // di luar ASCII -> '?'
      }
    }
    return out;
  }

  /// Ubah hasil render template menjadi byte siap kirim ke printer.
  static List<int> dariBaris(
    List<BarisStruk> baris, {
    int barisKosongAkhir = 4,
    bool potongKertas = false,
    bool fontKecil = false,
  }) {
    final p = EscPos();
    p.init(fontKecil: fontKecil);

    // Keadaan ditulis ulang di SETIAP baris, tidak dihemat dengan
    // membandingkan baris sebelumnya.
    //
    // Alasannya, ESC ! juga membawa bit tebal pada sebagian printer.
    // Kalau ukuran diubah tanpa menegaskan ulang tebal, huruf tebal bisa
    // ikut hilang di baris berikutnya. Selisihnya hanya belasan byte
    // per baris, jauh lebih murah daripada hasil cetak yang salah.
    //
    // Urutannya penting: ukuran dulu, baru tebal. ESC ! 0x00 yang
    // dikirim untuk mengembalikan ukuran normal juga mematikan tebal
    // di printer tertentu, jadi ESC E harus menyusul sesudahnya.
    for (final b in baris) {
      p.rata(b.rata);
      p.besar(b.besar);
      p.tebal(b.tebal);
      p.teks(b.teks);
    }

    // Kembalikan printer ke keadaan normal.
    p.besar(false);
    p.tebal(false);
    p.rata(0);

    if (potongKertas) {
      p.potong();
    } else {
      p.baris(barisKosongAkhir);
    }
    return p.selesai();
  }
}
