import 'package:flutter/material.dart';

import '../models/models.dart';
import '../print/printer_service.dart';
import '../print/receipt.dart';
import '../store/settings.dart';
import '../ui/umum.dart';
import '../utils/fmt.dart';

// Tiap baris digambar dengan gaya aslinya, bukan teks polos, supaya tag
// [H] dan [B] tidak terlihat seolah tidak berfungsi di pratinjau.
class KertasStruk extends StatelessWidget {
  final List<BarisStruk> baris;
  final int lebar;

  const KertasStruk({super.key, required this.baris, required this.lebar});

  @override
  Widget build(BuildContext context) {
    return KertasPutih(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: baris.map((b) {
          final efektif = Struk.lebarEfektif(lebar, b.besar);
          var t = b.teks;
          if (t.length > efektif) t = t.substring(0, efektif);

          return Text(
            t.isEmpty ? ' ' : t,
            textAlign: b.rata == 1
                ? TextAlign.center
                : (b.rata == 2 ? TextAlign.right : TextAlign.left),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: b.besar ? 21 : 11,
              fontWeight: b.tebal ? FontWeight.w900 : FontWeight.normal,
              height: 1.3,
              color: Colors.black,
            ),
          );
        }).toList(),
      ),
    );
  }
}

// Pratinjau sekumpulan baris siap cetak. True bila pengguna menekan cetak.
Future<bool> tampilkanPratinjauBaris(
  BuildContext context,
  List<BarisStruk> baris, {
  required String judul,
  required String keterangan,
  String labelCetak = 'Cetak',
  bool bisaCetak = true,
  Color? warnaJudul,
}) async {
  final lebar = Settings.instance.lebarKertas;

  final hasil = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(judul, style: TextStyle(color: warnaJudul)),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(keterangan,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 10),
            Flexible(
              child: SingleChildScrollView(
                child: KertasStruk(baris: baris, lebar: lebar),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Periksa dulu sebelum kertas terpakai.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(bisaCetak ? 'Batal' : 'Tutup'),
        ),
        if (bisaCetak)
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.print_outlined, size: 18),
            label: Text(labelCetak),
          ),
      ],
    ),
  );

  return hasil ?? false;
}

// Pratinjau struk sebuah nota, lengkap dengan semua salinannya.
Future<bool> tampilkanPratinjau(
  BuildContext context,
  Nota nota, {
  bool bisaCetak = true,
  String judul = 'Pratinjau Struk',
}) async {
  final s = Settings.instance;
  final salinan = nota.jumlahCetak ?? s.jumlahSalinan;

  return tampilkanPratinjauBaris(
    context,
    PrinterService.instance.susunBaris(nota),
    judul: judul,
    keterangan: '$salinan lembar  -  kertas ${s.lebarKertas} karakter  -  '
        '${nota.labelTotal.toLowerCase()} ${rupiah(nota.nilaiTampil)}',
    labelCetak: salinan > 1 ? 'Cetak $salinan Lembar' : 'Cetak',
    bisaCetak: bisaCetak,
  );
}
