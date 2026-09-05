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

  // DC2 T - cetak halaman uji bawaan printer.
  //
  // Dibaca langsung dari SDK resmi Rongta (EscCmd.getSelfTestCmd),
  // yang mengembalikan {0x12, 0x54}. Halaman ini dicetak oleh
  // FIRMWARE printer, bukan oleh aplikasi, jadi isinya menunjukkan
  // keadaan printer yang sebenarnya - termasuk alamat Bluetooth.
  void cetakMandiri() => _b.addAll([0x12, 0x54]);

  // CATATAN: TIDAK ADA perintah kepekatan untuk mode struk.
  //
  // Ini sudah diperiksa sampai ke sumbernya, bukan dikira-kira:
  //
  //   - Daftar perintah resmi RPP02N tidak memuat ESC 7, DC2 #,
  //     GS ( E, maupun GS |.
  //   - SDK Android resmi Rongta dibongkar isinya. Satu-satunya
  //     metode kepekatan yang ada adalah setTscCurrentDensity dan
  //     setZplCurrentDensity - dua-duanya untuk mode LABEL (TSC/ZPL),
  //     bukan mode struk. Di kelas perintah struk tidak ada satu pun
  //     metode kepekatan.
  //
  // ESC 7 dan DC2 # berasal dari papan CSN-A2/Adafruit, keluarga
  // firmware yang berbeda. Mengirimnya ke printer ini paling banter
  // diabaikan, paling buruk menyisakan huruf sampah di kertas -
  // persis simbol yang muncul di awal nota sebelumnya.
  //
  // Yang benar-benar menghitamkan di sini cuma ESC E (huruf tebal),
  // karena titiknya digambar lebih rapat oleh firmware.

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

  // #Halaman uji bawaan printer
  //
  // Dicetak oleh firmware printer sendiri, bukan disusun aplikasi.
  // Isinya keadaan printer yang sebenarnya, termasuk alamat Bluetooth
  // yang berguna kalau sambungannya bermasalah.
  static List<int> cetakMandiriBytes() {
    final p = EscPos()..init();
    p.cetakMandiri();
    return p.selesai();
  }

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
    bool tebalSemua = false,
  }) {
    final p = EscPos()..init(fontKecil: fontKecil);

    // Ketajaman dikerjakan dengan HURUF TEBAL, bukan perintah kepekatan.
    //
    // Printer ini tidak punya perintah kepekatan untuk mode struk -
    // sudah dipastikan dari daftar perintah resmi RPP02N dan dari SDK
    // Android Rongta sendiri. Yang tersedia cuma ESC E, dan itu memang
    // menghitamkan: firmware menggambar tiap huruf dengan titik lebih
    // rapat.
    //
    // Karena itu "Tebalkan semua baris" menyalakan tebal untuk SELURUH
    // struk, bukan cuma baris yang diberi tag [B] di template.

    // Ukuran dan tebal ditegaskan ulang tiap baris, bukan hanya saat
    // berubah: pada sebagian printer ESC ! 0x00 ikut mematikan tebal,
    // jadi ESC E harus selalu menyusul sesudahnya.
    for (final b in baris) {
      p.rata(b.rata);
      p.besar(b.skalaLebar, b.skalaTinggi);
      p.tebal(b.tebal || tebalSemua);
      p.teks(b.teks);
    }

    p.besar(1, 1);
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
