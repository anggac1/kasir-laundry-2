import 'dart:typed_data';
import 'dart:ui' as ui;

import '../print/escpos.dart';
import '../print/receipt.dart';

// Mencetak struk sebagai GAMBAR, bukan sebagai teks.
//
// Ini akal-akalan untuk kertas jelek, dan satu-satunya yang benar-benar
// bisa dikerjakan dari sisi aplikasi.
//
// Printer 58mm kelas ini tidak punya perintah kepekatan sama sekali -
// sudah dipastikan dengan membongkar SDK resmi pabrikannya: metode
// kepekatan yang ada cuma untuk mode label (TSC/ZPL), tidak ada satu pun
// di kelas perintah struk. Jadi menyuruh printer "cetak lebih hitam"
// memang mustahil.
//
// Yang MASIH bisa dilakukan: jangan kirim teks, kirim gambar. Dalam mode
// gambar, printer hanya menembakkan titik sesuai pola yang kita berikan.
// Berarti kita sendiri yang menentukan tiap titiknya - termasuk
// menebalkan huruf dengan menyalakan titik di sekelilingnya. Kertas yang
// buruk butuh lebih banyak titik menyala untuk terlihat hitam, dan itu
// persis yang bisa kita atur di sini.
class CetakGambar {
  CetakGambar._();

  // GS v 0 - cetak gambar raster.
  //
  // Ada di daftar perintah resmi RPP02N dan di SDK Rongta, jadi pasti
  // dikenali. Formatnya:
  //   1D 76 30 m xL xH yL yH [data]
  // dengan m=0 (ukuran normal), x dalam BYTE (8 titik per byte),
  // y dalam baris titik.
  static const _gs = 0x1D;

  // #Mengubah gambar jadi byte hitam-putih siap kirim
  //
  // [tebal] 0 = apa adanya, 1-3 makin tebal. Menebalkan dikerjakan
  // dengan melebarkan tiap titik hitam ke tetangganya, jadi huruf yang
  // tipis jadi lebih berisi tanpa berubah bentuk.
  // [ulang] 2 berarti tiap potongan gambar dikirim DUA KALI berturut-turut
  // sebelum kertas bergerak, jadi titik yang sama dipanaskan dua kali.
  //
  // Ini beda dengan mencetak ulang seluruh struk: di sini kertas belum
  // sempat bergeser, jadi tembakan kedua jatuh tepat di titik yang sama
  // dan hasilnya lebih hitam tanpa bayangan ganda.
  static Future<Uint8List?> dariGambar(
    ui.Image gambar, {
    int tebal = 0,
    int ambang = 160,
    int ulang = 1,
  }) async {
    final data =
        await gambar.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;

    final lebar = gambar.width;
    final tinggi = gambar.height;
    final piksel = data.buffer.asUint8List();

    // Tahap 1: jadikan hitam-putih.
    //
    // Kertas termal cuma bisa hitam atau kosong, tidak ada abu-abu.
    // Piksel yang lebih gelap daripada ambang dianggap hitam.
    final hitam = List<bool>.filled(lebar * tinggi, false);
    for (var i = 0; i < lebar * tinggi; i++) {
      final o = i * 4;
      // Bobot mata manusia terhadap merah-hijau-biru.
      final abu = (piksel[o] * 299 + piksel[o + 1] * 587 + piksel[o + 2] * 114)
          ~/ 1000;
      // Piksel tembus pandang dianggap kertas kosong.
      hitam[i] = piksel[o + 3] > 128 && abu < ambang;
    }

    // Tahap 2: tebalkan.
    //
    // Tiap titik hitam menular ke tetangganya. Diulang [tebal] kali,
    // jadi 1 = sedikit lebih berisi, 3 = paling tebal.
    var kini = hitam;
    for (var putaran = 0; putaran < tebal.clamp(0, 3); putaran++) {
      final berikut = List<bool>.filled(lebar * tinggi, false);
      for (var y = 0; y < tinggi; y++) {
        for (var x = 0; x < lebar; x++) {
          if (!kini[y * lebar + x]) continue;
          berikut[y * lebar + x] = true;
          // Menular ke kanan dan ke bawah saja.
          //
          // Ke segala arah membuat huruf melar sampai saling menempel
          // dan justru tidak terbaca. Dua arah sudah cukup menambah
          // titik menyala tanpa merusak bentuknya.
          if (x + 1 < lebar) berikut[y * lebar + x + 1] = true;
          if (y + 1 < tinggi) berikut[(y + 1) * lebar + x] = true;
        }
      }
      kini = berikut;
    }

    // Tahap 3: padatkan jadi bit, 8 titik per byte.
    final lebarByte = (lebar + 7) ~/ 8;
    final keluar = <int>[];

    // Dikirim per potongan, bukan sekaligus.
    //
    // Sebagian printer punya penyangga terbatas dan menolak gambar yang
    // terlalu tinggi dalam satu perintah. Dipotong per 24 baris titik,
    // ukuran yang aman di semua printer yang pernah diuji orang.
    const tinggiPotong = 24;
    for (var atas = 0; atas < tinggi; atas += tinggiPotong) {
      final tinggiIni =
          (atas + tinggiPotong > tinggi) ? tinggi - atas : tinggiPotong;

      // Isi potongan disusun sekali, lalu dipakai berulang.
      final isi = <int>[];
      for (var y = atas; y < atas + tinggiIni; y++) {
        for (var bx = 0; bx < lebarByte; bx++) {
          var b = 0;
          for (var bit = 0; bit < 8; bit++) {
            final x = bx * 8 + bit;
            if (x < lebar && kini[y * lebar + x]) {
              b |= 0x80 >> bit;
            }
          }
          isi.add(b);
        }
      }

      final kepala = [
        _gs, 0x76, 0x30, 0x00,
        lebarByte & 0xFF, (lebarByte >> 8) & 0xFF,
        tinggiIni & 0xFF, (tinggiIni >> 8) & 0xFF,
      ];

      for (var k = 0; k < ulang.clamp(1, 3); k++) {
        // Tembakan kedua dan seterusnya didahului ESC J 0: memajukan
        // kertas NOL titik. Perintah ini menutup baris berjalan tanpa
        // menggerakkan kertas, sehingga gambar berikutnya menimpa tepat
        // di tempat yang sama.
        if (k > 0) keluar.addAll([0x1B, 0x4A, 0x00]);
        keluar..addAll(kepala)..addAll(isi);
      }
    }

    return Uint8List.fromList(keluar);
  }

  // #Lebar gambar dalam piksel yang pas untuk kertas ini
  //
  // Kepala cetak 58mm punya 384 titik, yang 80mm punya 576. Melebihi itu
  // hanya terpotong, jadi lebarnya dikunci ke angka tersebut.
  static int lebarTitik(int lebarKolom) => lebarKolom <= 42 ? 384 : 576;

  // #Menyusun baris struk jadi gambar siap cetak
  static Future<ui.Image?> gambarStruk(
    List<BarisStruk> baris,
    int lebarKolom,
  ) async {
    final lebarPx = lebarTitik(lebarKolom).toDouble();

    // Ukuran huruf dihitung dari lebar kertas, sama seperti pembuat
    // gambar untuk dibagikan, supaya satu baris penuh pas mengisi
    // kepala cetak.
    final acuan = _ukurLebar('0' * lebarKolom, 100);
    final dasar = lebarPx * 0.98 / acuan * 100;

    final paragraf = <ui.Paragraph>[];
    final regangan = <double>[];
    var tinggiIsi = 0.0;

    for (final b in baris) {
      final efektif = Struk.lebarEfektif(lebarKolom, b.skalaLebar);
      var t = b.teks;
      if (t.length > efektif) t = t.substring(0, efektif);
      if (t.isEmpty) t = ' ';

      final p = _susun(
        t,
        ukuran: dasar * b.skalaLebar,
        tebal: b.tebal,
        rata: b.rata,
        lebar: lebarPx,
      );
      paragraf.add(p);
      regangan.add(b.skalaTinggi / b.skalaLebar);
      tinggiIsi += p.height * (b.skalaTinggi / b.skalaLebar);
    }

    if (tinggiIsi <= 0) return null;

    final perekam = ui.PictureRecorder();
    final kanvas = ui.Canvas(perekam);
    kanvas.drawRect(
      ui.Rect.fromLTWH(0, 0, lebarPx, tinggiIsi),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );

    var y = 0.0;
    for (var i = 0; i < paragraf.length; i++) {
      final p = paragraf[i];
      final regang = regangan[i];
      if (regang == 1) {
        kanvas.drawParagraph(p, ui.Offset(0, y));
      } else {
        kanvas
          ..save()
          ..translate(0, y)
          ..scale(1, regang);
        kanvas.drawParagraph(p, ui.Offset.zero);
        kanvas.restore();
      }
      y += p.height * regang;
    }

    return perekam.endRecording().toImage(lebarPx.round(), tinggiIsi.ceil());
  }

  static double _ukurLebar(String teks, double ukuran) {
    final pb = ui.ParagraphBuilder(ui.ParagraphStyle(
      fontFamily: 'monospace',
      fontSize: ukuran,
    ))
      ..addText(teks);
    final p = pb.build()
      ..layout(const ui.ParagraphConstraints(width: double.infinity));
    return p.maxIntrinsicWidth;
  }

  static ui.Paragraph _susun(
    String teks, {
    required double ukuran,
    required bool tebal,
    required int rata,
    required double lebar,
  }) {
    final gaya = ui.ParagraphStyle(
      fontFamily: 'monospace',
      fontSize: ukuran,
      textAlign: switch (rata) {
        1 => ui.TextAlign.center,
        2 => ui.TextAlign.right,
        _ => ui.TextAlign.left,
      },
      maxLines: 1,
    );
    final pb = ui.ParagraphBuilder(gaya)
      ..pushStyle(ui.TextStyle(
        color: const ui.Color(0xFF000000),
        fontSize: ukuran,
        fontWeight: tebal ? ui.FontWeight.w900 : ui.FontWeight.normal,
        fontFamily: 'monospace',
      ))
      ..addText(teks);
    return pb.build()..layout(ui.ParagraphConstraints(width: lebar));
  }

  // #Satu halaman berisi SEMUA kombinasi sekaligus
  //
  // Daripada mengubah setelan lalu mencetak, ubah lagi lalu cetak lagi -
  // semua kemungkinan dicetak berurutan dalam satu kertas, lengkap
  // dengan namanya. Tinggal lihat mana yang paling terbaca, lalu pasang
  // angka itu di Pengaturan.
  static Future<List<int>?> ujiSemua(int lebarKolom) async {
    try {
      final hasil = <int>[];

      // Kepala halaman ditulis sebagai TEKS biasa, supaya tetap
      // terbaca walau semua mode gambar ternyata gagal.
      final kepala = EscPos()..init();
      kepala.rata(1);
      kepala.tebal(true);
      kepala.teks('UJI KUALITAS CETAK');
      kepala.tebal(false);
      kepala.rata(0);
      kepala.teks('Pilih yang paling terbaca,');
      kepala.teks('lalu pasang di Pengaturan.');
      kepala.teks('');
      hasil.addAll(kepala.selesai());

      // [A] mode teks biasa - patokan pembanding.
      hasil.addAll(_blokTeks(lebarKolom, 'A. TEKS BIASA', tebal: false));
      hasil.addAll(_blokTeks(lebarKolom, 'B. TEKS TEBAL', tebal: true));

      // [C..] mode gambar: tiap ketebalan, sekali dan dua kali tembak.
      const daftar = [
        (1, 1, 'C. GAMBAR tebal 1'),
        (2, 1, 'D. GAMBAR tebal 2'),
        (1, 2, 'E. GAMBAR tebal 1 + 2x tembak'),
        (2, 2, 'F. GAMBAR tebal 2 + 2x tembak'),
      ];
      for (final (tebal, ulang, nama) in daftar) {
        final b = await _blokGambar(lebarKolom, nama, tebal, ulang);
        if (b != null) hasil.addAll(b);
      }

      final tutup = EscPos()..init();
      tutup.rata(1);
      tutup.teks('-- selesai --');
      tutup.rata(0);
      hasil
        ..addAll(tutup.selesai())
        ..addAll(selesai(4));
      return hasil;
    } catch (_) {
      return null;
    }
  }

  // #Satu blok contoh dalam mode teks
  static List<int> _blokTeks(int lebarKolom, String nama,
      {required bool tebal}) {
    final p = EscPos()..init();
    p.tebal(true);
    p.teks(nama);
    p.tebal(tebal);
    p.teks('Rp123.456  Budi Santoso');
    p.teks('=' * lebarKolom);
    p.tebal(false);
    p.teks('');
    return p.selesai();
  }

  // #Satu blok contoh dalam mode gambar
  static Future<List<int>?> _blokGambar(
      int lebarKolom, String nama, int tebal, int ulang) async {
    final baris = <BarisStruk>[
      BarisStruk(nama, tebal: true),
      const BarisStruk('Rp123.456  Budi Santoso'),
      BarisStruk('=' * lebarKolom),
    ];
    final gambar = await gambarStruk(baris, lebarKolom);
    if (gambar == null) return null;
    final data = await dariGambar(gambar, tebal: tebal, ulang: ulang);
    gambar.dispose();
    if (data == null) return null;

    final p = EscPos()..init();
    return [...p.selesai(), ...data, 0x0A];
  }

  // #Baris kosong sesudah gambar, supaya struk mudah disobek
  static List<int> selesai(int barisKosong) =>
      List.filled(barisKosong.clamp(0, 20), 0x0A);
}
