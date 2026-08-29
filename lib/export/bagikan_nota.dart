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
  Future<String> _buatPdf(Nota nota, String teks) async {
    final doc = pw.Document();
    // Lebar halaman mengikuti kertas struk, bukan A4: hasilnya terbaca
    // wajar di layar HP pelanggan, bukan secuil teks di pojok kertas.
    final lebarMm = Settings.instance.lebarKertas <= 42 ? 58.0 : 80.0;
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          lebarMm * PdfPageFormat.mm,
          double.infinity,
          marginAll: 6 * PdfPageFormat.mm,
        ),
        build: (ctx) => pw.Text(
          teks,
          style: pw.TextStyle(font: pw.Font.courier(), fontSize: 8.5),
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

      const skalaPiksel = 2.5;
      const tepi = 20.0;
      const dasarHuruf = 13.0;
      // Lebar kanvas dihitung dari lebar kertas, bukan angka tetap, supaya
      // struk 48 kolom tidak terpotong.
      final lebarIsi = lebarKolom * dasarHuruf * 0.62;
      final lebarTotal = lebarIsi + tepi * 2;

      // Tahap 1: susun tiap baris dan ukur tingginya lebih dulu.
      final paragraf = <ui.Paragraph>[];
      var tinggiIsi = 0.0;
      for (final b in baris) {
        final efektif = Struk.lebarEfektif(lebarKolom, b.skala);
        var t = b.teks;
        if (t.length > efektif) t = t.substring(0, efektif);
        if (t.isEmpty) t = ' ';

        final ukuran = (dasarHuruf * b.skala).clamp(dasarHuruf, 34.0);
        final gaya = ui.ParagraphStyle(
          textAlign: b.rata == EscPos.rataTengah
              ? TextAlign.center
              : (b.rata == EscPos.rataKanan
                  ? TextAlign.right
                  : TextAlign.left),
          fontFamily: 'monospace',
          fontSize: ukuran,
          height: 1.35,
        );
        final pb = ui.ParagraphBuilder(gaya)
          ..pushStyle(ui.TextStyle(
            color: const Color(0xFF000000),
            fontFamily: 'monospace',
            fontSize: ukuran,
            fontWeight: b.tebal ? FontWeight.w900 : FontWeight.normal,
          ))
          ..addText(t);
        final p = pb.build()
          ..layout(ui.ParagraphConstraints(width: lebarIsi));
        paragraf.add(p);
        tinggiIsi += p.height;
      }

      final tinggiTotal = tinggiIsi + tepi * 2;

      // Tahap 2: gambar di atas kertas putih.
      final perekam = ui.PictureRecorder();
      final kanvas = Canvas(perekam);
      kanvas.drawRect(
        Rect.fromLTWH(0, 0, lebarTotal, tinggiTotal),
        Paint()..color = const Color(0xFFFFFFFF),
      );
      var y = tepi;
      for (final p in paragraf) {
        kanvas.drawParagraph(p, Offset(tepi, y));
        y += p.height;
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
