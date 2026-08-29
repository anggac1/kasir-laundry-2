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

  // #Nama berkas yang aman dipakai di semua sistem berkas
  static String _namaBerkas(Nota nota, String ekstensi) {
    final kode = nota.kode.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    return 'nota_$kode.$ekstensi';
  }

  Future<bool> bagikan(
    BuildContext context,
    Nota nota,
    Set<FormatBagikan> format,
  ) async {
    if (format.isEmpty) return false;
    try {
      final berkas = <XFile>[];
      final teks = teksStruk(nota);

      if (format.contains(FormatBagikan.pdf)) {
        berkas.add(XFile(await _buatPdf(nota, teks)));
      }
      if (format.contains(FormatBagikan.gambar)) {
        final path = await _buatGambar(nota);
        if (path != null) berkas.add(XFile(path));
      }

      // Teks tanpa berkas dibagikan sebagai pesan biasa; kalau ada
      // berkasnya, teks itu jadi keterangan yang menyertainya.
      final adaTeks = format.contains(FormatBagikan.teks);
      if (berkas.isEmpty) {
        await Share.share(teks, subject: 'Nota ${nota.kode}');
      } else {
        await Share.shareXFiles(
          berkas,
          text: adaTeks ? teks : 'Nota ${nota.kode}',
          subject: 'Nota ${nota.kode}',
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // #Struk dicetak ke PDF dengan huruf monospace, supaya kolomnya lurus
  Future<String> buatPdf(Nota nota, String teks) => _buatPdf(nota, teks);

  Future<String?> buatGambar(Nota nota) => _buatGambar(nota);

  Future<String> _buatPdf(Nota nota, String teks) async {
    final doc = pw.Document();
    final lebarKolom = Settings.instance.lebarKertas;
    final baris = _baris(nota);

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
    final dasar = ruang / (lebarKolom * kLebarCourier);
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
    final path = '${dir.path}/${_namaBerkas(nota, 'pdf')}';
    await File(path).writeAsBytes(await doc.save(), flush: true);
    return path;
  }

  // #Struk digambar jadi PNG langsung di atas kanvas
  //
  // Sengaja tidak memakai pohon widget di luar layar: cara itu bergantung
  // pada API dalaman Flutter yang berubah antar versi. Menggambar dengan
  // dart:ui memakai API yang stabil dan hasilnya bisa dipastikan.
  Future<String?> _buatGambar(Nota nota) async {
    try {
      final baris = _baris(nota);
      final lebarKolom = Settings.instance.lebarKertas;

      // Digambar 4x lebih besar daripada ukuran layar, lalu disimpan apa
      // adanya. Hasilnya tajam saat dibuka besar di WhatsApp, dan tidak
      // terlihat sebagai gambar mungil di daftar chat.
      const skalaPiksel = 4.0;
      const tepi = 16.0;
      const dasarHuruf = 14.0;

      // Lebar kertas DIUKUR dari font sungguhan, bukan ditebak.
      //
      // Versi sebelumnya memakai angka tetap 0,62 sebagai perkiraan lebar
      // satu huruf monospace. Kalau font di HP ternyata lebih sempit,
      // teksnya tidak memenuhi kanvas dan gambarnya jadi separuh kosong.
      // Sekarang satu baris penuh diukur lebih dulu, dan hasilnya yang
      // dipakai sebagai lebar kertas.
      final lebarIsi = _ukurLebar('W' * lebarKolom, dasarHuruf);
      final lebarTotal = lebarIsi + tepi * 2;

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
      final path = '${dir.path}/${_namaBerkas(nota, 'png')}';
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

// Menanyakan format sebelum berbagi. Boleh lebih dari satu sekaligus.
// Mengembalikan null bila dibatalkan.
Future<Set<FormatBagikan>?> pilihFormatBagikan(BuildContext context) async {
  final dipilih = <FormatBagikan>{FormatBagikan.teks};

  return showDialog<Set<FormatBagikan>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialog) => AlertDialog(
        title: const Text('Bagikan nota sebagai'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Boleh pilih lebih dari satu. Semuanya dikirim lewat menu '
              'berbagi bawaan HP, jadi bisa ke WhatsApp, email, atau '
              'disimpan ke folder.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            _pilihan(
              ctx,
              setDialog,
              dipilih,
              FormatBagikan.teks,
              Icons.text_fields,
              'Teks',
              'Langsung terbaca di chat. Ukuran huruf tidak ikut, '
                  'karena WhatsApp tidak mengenalnya.',
            ),
            _pilihan(
              ctx,
              setDialog,
              dipilih,
              FormatBagikan.pdf,
              Icons.picture_as_pdf_outlined,
              'PDF',
              'Rapi dan bisa dicetak ulang pelanggan.',
            ),
            _pilihan(
              ctx,
              setDialog,
              dipilih,
              FormatBagikan.gambar,
              Icons.image_outlined,
              'Gambar (PNG)',
              'Paling mirip struk aslinya, ukuran huruf ikut terlihat.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: dipilih.isEmpty
                ? null
                : () => Navigator.pop(ctx, Set<FormatBagikan>.from(dipilih)),
            child: const Text('Bagikan'),
          ),
        ],
      ),
    ),
  );
}

// #Satu baris pilihan format dengan kotak centang
Widget _pilihan(
  BuildContext ctx,
  void Function(void Function()) setDialog,
  Set<FormatBagikan> dipilih,
  FormatBagikan nilai,
  IconData ikon,
  String judul,
  String keterangan,
) {
  final aktif = dipilih.contains(nilai);
  return CheckboxListTile(
    value: aktif,
    dense: true,
    contentPadding: EdgeInsets.zero,
    controlAffinity: ListTileControlAffinity.leading,
    secondary: Icon(ikon, size: 20),
    title: Text(judul, style: const TextStyle(fontSize: 14)),
    subtitle: Text(keterangan, style: const TextStyle(fontSize: 11)),
    onChanged: (v) => setDialog(() {
      if (v == true) {
        dipilih.add(nilai);
      } else {
        dipilih.remove(nilai);
      }
    }),
  );
}
