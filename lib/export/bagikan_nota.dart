import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../print/escpos.dart';
import '../print/printer_service.dart';
import '../print/receipt.dart';
import '../store/settings.dart';
import '../utils/fmt.dart';

// Membagikan satu nota ke pelanggan lewat menu berbagi bawaan HP.
//
// Tidak memakai API WhatsApp mana pun: berkasnya dibuat lokal lalu
// diserahkan ke Android, persis seperti Ekspor laporan. Ringan, dan
// pelanggan bisa dikirimi lewat aplikasi apa saja.
enum FormatBagikan { teks, pdf, gambar }

class BagikanNota {
  BagikanNota._();
  static final BagikanNota instance = BagikanNota._();

  // Isi struk diambil dari penyusun baris yang SAMA dengan pratinjau dan
  // pencetakan. Dengan begitu yang diterima pelanggan tidak pernah berbeda
  // dari yang dilihat kasir di layar.
  static List<BarisStruk> _baris(Nota nota) =>
      PrinterService.instance.susunBaris(nota, paksaSalinan: 1);

  // #Baris yang sama persis dengan yang dipakai membuat gambar dan PDF
  //
  // Dibuka aksesnya supaya layar pratinjau menggambar dari sumber yang
  // sama, bukan menyusun ulang dengan aturannya sendiri.
  static List<BarisStruk> barisStruk(Nota nota) => _baris(nota);

  // #Struk sebagai teks biasa, siap ditempel di chat
  //
  // WhatsApp tidak mengenal ukuran huruf, jadi tag [C2] dan [B] hanya
  // memengaruhi perataan dan lebar kolomnya, bukan besar hurufnya.
  static String teksStruk(Nota nota) => Struk.pratinjau(
        _baris(nota),
        Settings.instance.lebarKertas,
        rapikan: true,
      );

  // #Nama berkas yang diterima pelanggan
  //
  // Kode internal seperti LDY-260830-001 tidak dipakai: pelanggan tidak
  // punya urusan dengan nomor urut toko, dan itu terlihat tidak rapi di
  // daftar berkas WhatsApp. Yang dipakai pola yang bisa diatur sendiri
  // di Pengaturan, misalnya "Nota {nama} {tanggal}".
  static String namaBerkas(Nota nota, String ekstensi) {
    final pola = Settings.instance.polaNamaBerkas;
    var hasil = pola
        .replaceAll('{nama}', nota.pelanggan)
        .replaceAll('{tanggal}', tanggalBerkas(nota.dibuat))
        .replaceAll('{toko}', Settings.instance.namaToko)
        .replaceAll('{no_nota}', nota.kode);
    // Karakter yang dilarang di nama berkas dibuang, bukan diganti,
    // supaya hasilnya tetap enak dibaca.
    hasil = hasil.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), ' ');
    hasil = hasil.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (hasil.isEmpty) hasil = 'Nota';
    // Batas aman nama berkas di Android.
    if (hasil.length > 80) hasil = hasil.substring(0, 80).trim();
    return '$hasil.$ekstensi';
  }

  // #Tanggal untuk nama berkas, tanpa karakter yang dilarang
  static String tanggalBerkas(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-${d.year}';

  // #Kata pengantar yang menemani lampiran
  //
  // Ini SAPAAN, bukan isi struk. Struknya sudah ada di gambar atau PDF
  // yang dilampirkan; menempelkan isinya lagi di badan pesan berarti
  // pelanggan menerima struk dua kali dalam satu kiriman.
  //
  // Polanya bisa diatur sendiri, memakai placeholder yang sama dengan
  // nama berkas supaya tidak ada kosakata baru yang perlu dihafal.
  static String pesanPengantar(Nota nota) {
    final toko = Settings.instance.namaToko.trim();
    var hasil = Settings.instance.pesanPengantar
        .replaceAll('{nama}', nota.pelanggan)
        .replaceAll('{toko}', toko)
        .replaceAll('{tanggal}', tanggalBerkas(nota.dibuat))
        .replaceAll('{no_nota}', nota.kode)
        .replaceAll('{total}', rupiah(nota.nilaiTampil));
    hasil = hasil.trim();
    // Pola yang dikosongkan pengguna tidak boleh membuat pesan hilang
    // sama sekali, karena beberapa aplikasi chat menolak kiriman tanpa
    // teks sedikit pun.
    if (hasil.isEmpty) hasil = toko.isEmpty ? 'Nota Anda' : 'Nota dari $toko';
    return hasil;
  }

  // Membagikan SATU format saja.
  //
  // Sebelumnya bisa beberapa sekaligus, tapi WhatsApp memperlakukan
  // kiriman berisi banyak berkas sebagai album dan pesan pengantarnya
  // sering hilang. Satu berkas per kiriman lebih dapat diandalkan, dan
  // pelanggan tidak perlu memilih mana yang harus dibuka.
  //
  // Gambar dan PDF dikirim bersama KATA PENGANTAR dalam satu pesan,
  // bukan bersama isi struknya: WhatsApp menaruh teks itu sebagai
  // keterangan di bawah lampiran, jadi yang pantas di sana kalimat
  // sapaan, seperti orang mengirim pesan biasa.
  Future<bool> bagikan(
    BuildContext context,
    Nota nota,
    FormatBagikan format,
  ) async {
    try {
      final teks = teksStruk(nota);
      final pengantar = pesanPengantar(nota);

      switch (format) {
        case FormatBagikan.teks:
          await Share.share(teks, subject: pengantar);
        case FormatBagikan.pdf:
          await Share.shareXFiles(
            [XFile(await _buatPdf(nota, teks))],
            text: pengantar,
            subject: pengantar,
          );
        case FormatBagikan.gambar:
          final path = await _buatGambar(nota);
          if (path == null) return false;
          await Share.shareXFiles(
            [XFile(path)],
            text: pengantar,
            subject: pengantar,
          );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // #Struk dicetak ke PDF dengan huruf monospace, supaya kolomnya lurus
  Future<String> buatPdf(Nota nota, String teks,
          {List<BarisStruk>? barisLuar}) =>
      _buatPdf(nota, teks, barisLuar: barisLuar);

  Future<String?> buatGambar(Nota nota, {List<BarisStruk>? barisLuar}) =>
      _buatGambar(nota, barisLuar: barisLuar);

  Future<String> _buatPdf(Nota nota, String teks,
      {List<BarisStruk>? barisLuar}) async {
    final doc = pw.Document();
    final lebarKolom = Settings.instance.lebarKertas;
    // Pratinjau template mengirim baris hasil teks yang SEDANG diketik.
    // Tanpa ini, yang tampil selalu template terakhir yang tersimpan.
    final baris = barisLuar ?? _baris(nota);

    // Lebar halaman mengikuti kertas struk, bukan A4.
    final lebarMm = lebarKolom <= 42 ? 58.0 : 80.0;
    final lebarHalaman = lebarMm * PdfPageFormat.mm;
    const tepi = 5.0 * PdfPageFormat.mm;
    final ruang = lebarHalaman - tepi * 2;

    // Ukuran huruf DIHITUNG dari lebar kertas, bukan angka tetap.
    //
    // Courier Type 1 lebar tiap hurufnya persis 0,6 x ukuran huruf. Itu
    // angka baku format PDF, bukan perkiraan. Sebelumnya dipatok 8,5 pt,
    // sehingga hanya muat 25 karakter dari 32 dan setiap baris melipat
    // jadi dua.
    const kLebarCourier = 0.6;

    // Ukuran dihitung dari baris TERLEBAR yang benar-benar ada, bukan
    // dari asumsi semua baris berskala 1.
    //
    // Baris [B2] memakai 16 kolom tapi hurufnya dua kali besar, jadi
    // lebar cetaknya tetap 32 kolom. Kalau ukurannya dihitung seolah
    // semua baris berskala 1, baris berskala itu melebihi kertas dan
    // paket pdf mengecilkannya diam-diam sampai muat. Itu sebabnya
    // TOTAL sempat tercetak sama besar dengan baris biasa.
    var kolomTerpakai = lebarKolom;
    for (final b in baris) {
      final efektif = Struk.lebarEfektif(lebarKolom, b.skalaLebar);
      final panjang = b.teks.length > efektif ? efektif : b.teks.length;
      final kolom = panjang * b.skalaLebar;
      if (kolom > kolomTerpakai) kolomTerpakai = kolom;
    }

    // Disisakan 1 persen, jangan pas-pasan.
    //
    // Baris yang lebarnya PERSIS sama dengan ruang yang tersedia berada
    // di ambang: pembulatan di dalam paket pdf bisa menganggapnya lebih
    // lebar sedikit, lalu melipatnya ke baris kedua. Itulah sebabnya
    // "sed do eiusmod tempor ut labore" pecah padahal hitungannya muat.
    // Kelonggaran satu persen menghilangkan ambang itu tanpa terlihat.
    const kelonggaran = 0.99;
    final dasar = ruang * kelonggaran / (kolomTerpakai * kLebarCourier);
    final monospace = pw.Font.courier();
    final monospaceTebal = pw.Font.courierBold();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          lebarHalaman,
          double.infinity,
          marginAll: tepi,
        ),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          mainAxisSize: pw.MainAxisSize.min,
          // Digambar per baris dari daftar BarisStruk, bukan dari teks
          // polos. Dengan begitu tag ukuran dan tebal ikut terlihat,
          // sama seperti di kertas dan di gambar.
          children: baris.map((b) {
            final efektif = Struk.lebarEfektif(lebarKolom, b.skalaLebar);
            var t = b.teks;
            if (t.length > efektif) t = t.substring(0, efektif);

            // Ukuran huruf mengikuti LEBAR, karena itu yang menentukan
            // berapa karakter muat sebaris.
            //
            // Tinggi yang berbeda ([C1.5] = lebar 1 tinggi 2) tidak bisa
            // diregangkan di PDF: paket pdf hanya punya Transform.scale
            // yang seragam, dan matriksnya butuh paket tambahan. Yang
            // dilakukan di sini memberi baris itu ruang vertikal lebih
            // lega lewat lineSpacing, sehingga tetap terbaca sebagai
            // baris yang lebih menonjol.
            final ukuran = dasar * b.skalaLebar;
            final regang = b.skalaTinggi / b.skalaLebar;

            final teks = pw.Text(
              t.isEmpty ? ' ' : t,
              textAlign: b.rata == EscPos.rataTengah
                  ? pw.TextAlign.center
                  : (b.rata == EscPos.rataKanan
                      ? pw.TextAlign.right
                      : pw.TextAlign.left),
              maxLines: 1,
              softWrap: false,
              style: pw.TextStyle(
                font: b.tebal ? monospaceTebal : monospace,
                fontSize: ukuran,
                // Disamakan dengan gambar: tinggi baris 1,25 x ukuran
                // huruf, ditambah ruang untuk baris yang lebih tinggi.
                lineSpacing: ukuran * (0.25 + (regang - 1)),
              ),
            );

            return teks;
          }).toList(),
        ),
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/${namaBerkas(nota, 'pdf')}';
    await File(path).writeAsBytes(await doc.save(), flush: true);
    return path;
  }

  // #Struk digambar jadi PNG langsung di atas kanvas
  //
  // Sengaja tidak memakai pohon widget di luar layar: cara itu bergantung
  // pada API dalaman Flutter yang berubah antar versi. Menggambar dengan
  // dart:ui memakai API yang stabil dan hasilnya bisa dipastikan.
  Future<String?> _buatGambar(Nota nota,
      {List<BarisStruk>? barisLuar}) async {
    try {
      final baris = barisLuar ?? _baris(nota);
      final lebarKolom = Settings.instance.lebarKertas;

      // Lebar gambar diatur di Pengaturan, dalam piksel.
      //
      // Ukuran hurufnya dihitung MUNDUR dari lebar itu, bukan sebaliknya.
      // Jadi gambar 800 piksel benar-benar 800 piksel dengan tulisan yang
      // pas memenuhinya, bukan gambar kecil yang diperbesar.
      final lebarTotal = Settings.instance.lebarGambar.toDouble();
      final tepi = lebarTotal * 0.04;
      final lebarIsi = lebarTotal - tepi * 2;

      // Ukuran huruf yang membuat satu baris penuh pas selebar lebarIsi.
      // Diukur dari font sungguhan, bukan menebak rasionya, lalu
      // dikurangi satu persen supaya tidak berada di ambang melipat.
      final lebarAcuan = _ukurLebar('0' * lebarKolom, 100.0);
      final dasarHuruf = lebarIsi * 0.99 / lebarAcuan * 100.0;

      // Digambar 1:1, karena ukurannya sudah ditentukan di atas.
      const skalaPiksel = 1.0;

      // Tahap 1: susun tiap baris dan ukur tingginya lebih dulu.
      final paragraf = <ui.Paragraph>[];
      final regangan = <double>[];
      var tinggiIsi = 0.0;
      for (final b in baris) {
        final efektif = Struk.lebarEfektif(lebarKolom, b.skalaLebar);
        var t = b.teks;
        if (t.length > efektif) t = t.substring(0, efektif);
        if (t.isEmpty) t = ' ';

        // Ukuran mengikuti LEBAR; tinggi yang berbeda ([C1.5] misalnya)
        // diwujudkan dengan meregangkan kanvas saat menggambar, sama
        // seperti printer yang menumbuhkan huruf ke bawah saja.
        final ukuran = dasarHuruf * b.skalaLebar;
        final regang = b.skalaTinggi / b.skalaLebar;
        final p = _susunParagraf(
          t,
          ukuran: ukuran,
          tebal: b.tebal,
          rata: b.rata,
          lebar: lebarIsi,
        );
        paragraf.add(p);
        regangan.add(regang);
        tinggiIsi += p.height * regang;
      }

      final tinggiTotal = tinggiIsi + tepi * 2;

      // Tahap 2: gambar di atas kertas putih.
      final perekam = ui.PictureRecorder();
      final kanvas = Canvas(perekam);

      // WAJIB: kanvasnya ikut diperbesar sebelum menggambar.
      //
      // toImage() hanya menentukan ukuran BINGKAI hasil, bukan ukuran
      // gambarnya. Tanpa scale ini, struk tetap digambar sebesar ukuran
      // logisnya lalu ditaruh di pojok kiri atas bingkai yang empat kali
      // lebih besar, dan sisanya kosong. Itulah "gambar mungil" yang
      // terlihat sebelumnya.
      kanvas.scale(skalaPiksel);

      kanvas.drawRect(
        Rect.fromLTWH(0, 0, lebarTotal, tinggiTotal),
        Paint()..color = const Color(0xFFFFFFFF),
      );
      var y = tepi;
      for (var i = 0; i < paragraf.length; i++) {
        final p = paragraf[i];
        final regang = regangan[i];
        if (regang == 1) {
          kanvas.drawParagraph(p, Offset(tepi, y));
        } else {
          // Diregangkan ke bawah saja, lebarnya tetap.
          kanvas
            ..save()
            ..translate(tepi, y)
            ..scale(1, regang);
          kanvas.drawParagraph(p, Offset.zero);
          kanvas.restore();
        }
        y += p.height * regang;
      }

      final gambar = await perekam.endRecording().toImage(
            (lebarTotal * skalaPiksel).round(),
            (tinggiTotal * skalaPiksel).round(),
          );
      final data = await gambar.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return null;

      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/${namaBerkas(nota, 'png')}';
      await File(path).writeAsBytes(data.buffer.asUint8List(), flush: true);
      return path;
    } catch (_) {
      // Gambar adalah pilihan tambahan. Kalau gagal, teks dan PDF tetap
      // terkirim, jadi pembagiannya tidak ikut batal.
      return null;
    }
  }

  // #Mengukur lebar sebenarnya sepotong teks pada ukuran huruf tertentu
  static double _ukurLebar(String teks, double ukuran) {
    final pb = ui.ParagraphBuilder(ui.ParagraphStyle(
      fontFamily: 'monospace',
      fontSize: ukuran,
    ))
      ..pushStyle(ui.TextStyle(fontFamily: 'monospace', fontSize: ukuran))
      ..addText(teks);
    final p = pb.build()
      ..layout(const ui.ParagraphConstraints(width: double.infinity));
    return p.maxIntrinsicWidth;
  }

  // #Satu baris siap gambar
  static ui.Paragraph _susunParagraf(
    String teks, {
    required double ukuran,
    required bool tebal,
    required int rata,
    required double lebar,
  }) {
    final gaya = ui.ParagraphStyle(
      textAlign: rata == EscPos.rataTengah
          ? TextAlign.center
          : (rata == EscPos.rataKanan ? TextAlign.right : TextAlign.left),
      fontFamily: 'monospace',
      fontSize: ukuran,
      height: 1.25,
      // maxLines sengaja tidak dipasang. Teksnya sudah dipotong tepat
      // sepanjang kolom yang muat, jadi tidak akan melipat; memasang
      // batas justru berisiko memangkas huruf terakhir pada sebagian
      // mesin teks.
    );
    final pb = ui.ParagraphBuilder(gaya)
      ..pushStyle(ui.TextStyle(
        color: const Color(0xFF000000),
        fontFamily: 'monospace',
        fontSize: ukuran,
        fontWeight: tebal ? FontWeight.w900 : FontWeight.normal,
      ))
      ..addText(teks);
    return pb.build()..layout(ui.ParagraphConstraints(width: lebar));
  }
}
