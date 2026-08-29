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

  // Cetak ganda: tiap titik dipanaskan DUA KALI dalam satu lintasan,
  // tanpa kertas bergerak di antaranya.
  //
  // Ini jawaban yang benar untuk "cetak dua kali": mengulang seluruh
  // struk secara fisik berisiko meleset karena kertas sudah terlanjur
  // ditarik, sedangkan ESC G dikerjakan printer per baris titik, jadi
  // mustahil bergeser. Hasilnya lebih hitam pada kertas yang jelek.
  void cetakGanda(bool on) => _b.addAll([_esc, 0x47, on ? 1 : 0]);

  // Atur lama pemanasan dan jeda antar baris titik.
  //
  //   titikMaks : banyak titik yang dipanaskan sekaligus, satuan 8 titik
  //   lamaPanas : lama pemanasan, satuan 10 mikrodetik
  //   jeda      : jeda antar baris titik, satuan 10 mikrodetik
  //
  // Makin lama pemanasannya makin hitam hasilnya, tapi makin panas pula
  // kepala printernya. Makin besar jedanya makin lambat mencetak, dan
  // itu justru membantu: kertas murah butuh waktu lebih untuk menghitam.
  void panas(int titikMaks, int lamaPanas, int jeda) {
    _b.addAll([
      _esc,
      0x37,
      titikMaks.clamp(0, 255),
      lamaPanas.clamp(3, 255),
      jeda.clamp(0, 255),
    ]);
  }

  // Lebar dan tinggi diatur TERPISAH, 1 sampai 8 masing-masing.
  //
  // Inilah yang memungkinkan ukuran "setengah": lebar 1 tinggi 2 memberi
  // huruf yang lebih tinggi tapi tetap selebar biasa, jadi satu barisnya
  // masih muat 32 kolom. Kelipatan pecahan pada lebar tidak mungkin,
  // perangkat kerasnya memang hanya mengenal bilangan bulat.
  //
  // Dua perintah dikirim sekaligus karena printer murah tidak seragam:
  // GS ! dipahami mayoritas, ESC ! dipahami sebagian printer lama yang
  // mengabaikan GS !. ESC ! cuma punya satu tingkat, jadi dinyalakan
  // untuk ukuran apa pun di atas normal.
  void besar(int skalaLebar, [int? skalaTinggi]) {
    final w = skalaLebar.clamp(1, 8) - 1;
    final h = (skalaTinggi ?? skalaLebar).clamp(1, 8) - 1;
    // GS ! : 4 bit atas = lebar, 4 bit bawah = tinggi.
    _b.addAll([_gs, 0x21, (w << 4) | h]);
    // ESC ! : 0x20 lebar dobel, 0x10 tinggi dobel.
    var esc = 0x00;
    if (w > 0) esc |= 0x20;
    if (h > 0) esc |= 0x10;
    _b.addAll([_esc, 0x21, esc]);
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

  // #Lama pemanasan menurut tingkat ketajaman. 80 adalah bawaan pabrik.
  static int _lamaPanas(int tingkat) => switch (tingkat) {
        1 => 100,
        2 => 140,
        3 => 190,
        _ => 80,
      };

  // #Jeda antar baris titik menurut tingkat kelambatan. 2 adalah bawaan.
  static int _jeda(int tingkat) => switch (tingkat) {
        1 => 20,
        2 => 40,
        _ => 2,
      };

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
    int ketajaman = 0,
    int kelambatan = 0,
  }) {
    final p = EscPos()..init(fontKecil: fontKecil);

    // Perintah ketajaman hanya dikirim bila memang diminta. Printer yang
    // tidak mengenalinya bisa mencetak sampah, jadi pada setelan Normal
    // tidak ada satu byte tambahan pun yang dikirim.
    if (ketajaman > 0 || kelambatan > 0) {
      p.panas(7, _lamaPanas(ketajaman), _jeda(kelambatan));
    }
    if (ketajaman >= 1) p.cetakGanda(true);

    // Ukuran dan tebal ditegaskan ulang tiap baris, bukan hanya saat
    // berubah: pada sebagian printer ESC ! 0x00 ikut mematikan tebal,
    // jadi ESC E harus selalu menyusul sesudahnya.
    for (final b in baris) {
      p.rata(b.rata);
      p.besar(b.skalaLebar, b.skalaTinggi);
      p.tebal(b.tebal);
      p.teks(b.teks);
    }

    p.besar(1, 1);
    p.tebal(false);
    p.rata(rataKiri);
    if (ketajaman >= 1) p.cetakGanda(false);

    if (potongKertas) {
      p.potong();
    } else {
      p.baris(barisKosongAkhir);
    }
    return p.selesai();
  }
}
