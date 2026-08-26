import 'receipt.dart';

// Penyusun byte ESC/POS. Ditulis sendiri tanpa paket tambahan supaya
// dependensi build minimal dan perilakunya bisa dipastikan.
class EscPos {
  static const _esc = 0x1B;
  static const _gs = 0x1D;

  // 0 kiri, 1 tengah, 2 kanan.
  static const rataKiri = 0;
  static const rataTengah = 1;
  static const rataKanan = 2;

  final List<int> _b = [];

  void init({bool fontKecil = false}) {
    _b.addAll([_esc, 0x40]); // ESC @  reset
    _b.addAll([_esc, 0x74, 0x00]); // ESC t  code page PC437
    _b.addAll([_esc, 0x52, 0x00]); // ESC R  charset USA
    // ESC M  0 = Font A (32 kolom), 1 = Font B (42 kolom)
    _b.addAll([_esc, 0x4D, fontKecil ? 0x01 : 0x00]);
  }

  void rata(int n) => _b.addAll([_esc, 0x61, n.clamp(rataKiri, rataKanan)]);

  void tebal(bool on) => _b.addAll([_esc, 0x45, on ? 1 : 0]);

  // Dua perintah sekaligus karena printer murah tidak seragam: GS ! dipahami
  // mayoritas, ESC ! dipahami sebagian printer lama yang mengabaikan GS !.
  void besar(bool on) {
    _b.addAll([_gs, 0x21, on ? 0x11 : 0x00]);
    _b.addAll([_esc, 0x21, on ? 0x30 : 0x00]);
  }

  void teks(String s) {
    _b.addAll(keAscii(s).codeUnits);
    _b.add(0x0A);
  }

  void baris(int n) => _b.addAll(List.filled(n.clamp(0, 20), 0x0A));

  void potong() {
    baris(3);
    _b.addAll([_gs, 0x56, 0x00]); // GS V  full cut
  }

  List<int> selesai() => List<int>.unmodifiable(_b);

  // Printer thermal tidak paham UTF-8. Huruf beraksen diturunkan ke ASCII,
  // sisanya jadi '?'. Dipakai juga oleh receipt.dart untuk mengukur lebar
  // baris, supaya perataan kiri-kanan tidak meleset pada teks non-ASCII.
  static String keAscii(String s) {
    final buf = StringBuffer();
    for (final ch in s.split('')) {
      final ganti = _padanan[ch];
      if (ganti != null) {
        buf.write(ganti);
        continue;
      }
      buf.write(ch.codeUnitAt(0) < 128 ? ch : '?');
    }
    return buf.toString();
  }

  static const _padanan = {
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
  };

  // Ubah hasil render template jadi byte siap kirim.
  static List<int> dariBaris(
    List<BarisStruk> baris, {
    int barisKosongAkhir = 4,
    bool potongKertas = false,
    bool fontKecil = false,
  }) {
    final p = EscPos()..init(fontKecil: fontKecil);

    // Ukuran dan tebal ditegaskan ulang tiap baris, bukan hanya saat
    // berubah: pada sebagian printer ESC ! 0x00 ikut mematikan tebal,
    // jadi ESC E harus selalu menyusul sesudahnya.
    for (final b in baris) {
      p.rata(b.rata);
      p.besar(b.besar);
      p.tebal(b.tebal);
      p.teks(b.teks);
    }

    p.besar(false);
    p.tebal(false);
    p.rata(rataKiri);

    if (potongKertas) {
      p.potong();
    } else {
      p.baris(barisKosongAkhir);
    }
    return p.selesai();
  }
}
