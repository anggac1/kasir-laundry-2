import 'package:flutter/material.dart';

import '../models/models.dart';
import '../print/printer_service.dart';
import '../print/receipt.dart';
import '../store/settings.dart';
import '../ui/umum.dart';
import '../utils/fmt.dart';

// SATU-SATUNYA penggambar struk di layar.
//
// Dipakai oleh pratinjau template, pratinjau sebelum cetak, dan pratinjau
// bagikan. Sebelumnya tiap layar punya aturannya sendiri, sehingga struk
// yang sama tampil berbeda di tiga tempat. Aturannya sekarang cuma ada
// di sini, jadi tidak bisa lagi menyimpang satu sama lain.
//
// Aturannya sama dengan yang dipakai gambar dan PDF:
//   - lebar kertas = lebar 1 baris penuh pada ukuran huruf dasar
//   - skala 2 berarti 2x lebar DAN tinggi, tanpa batas atas
//   - tinggi baris 1,25x ukuran huruf
class KertasStruk extends StatelessWidget {
  final List<BarisStruk> baris;
  final int lebar;

  // Ukuran huruf dasar. Diisi hanya bila layarnya butuh ukuran khusus;
  // biasanya dibiarkan null supaya menyesuaikan lebar yang tersedia.
  final double? dasarHuruf;

  const KertasStruk({
    super.key,
    required this.baris,
    required this.lebar,
    this.dasarHuruf,
  });

  // Ukuran huruf acuan saat mengukur. Nilainya tidak penting; yang
  // dipakai hanya perbandingan lebar hasil ukur terhadap angka ini.
  static const double _acuan = 20.0;

  // #Mengukur lebar sebenarnya satu baris penuh, bukan menebak rasionya
  //
  // Rasio lebar huruf monospace berbeda antar HP. Menebaknya membuat
  // teks kadang lebih lebar daripada ruang yang ada, dan Text yang
  // kelebaran akan MELIPAT: itu sebabnya "TOTAL Rp5.000" pernah pecah
  // jadi dua baris dan menyisakan "-" sendirian.
  static double _ukurSatuBaris(int kolom) {
    final tp = TextPainter(
      text: TextSpan(
        text: '0' * kolom,
        style: const TextStyle(fontFamily: 'monospace', fontSize: _acuan),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return tp.width;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, batas) {
        final ruang = batas.maxWidth.isFinite ? batas.maxWidth : 320.0;

        // Ukuran huruf terbesar yang masih memuat satu baris penuh.
        // Dikurangi setengah piksel sebagai jaga-jaga terhadap pembulatan
        // saat menggambar, supaya tidak ada baris yang melipat.
        final lebarAcuan = _ukurSatuBaris(lebar);
        final dasar = dasarHuruf ?? ((ruang - 0.5) / lebarAcuan * _acuan);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: baris.map((b) {
            final efektif = Struk.lebarEfektif(lebar, b.skala);
            var t = b.teks;
            if (t.length > efektif) t = t.substring(0, efektif);

            // Lebar dan tinggi bisa berbeda, misalnya [C1.5] yang lebar
            // 1 tinggi 2. Ukuran huruf mengikuti LEBAR, lalu tingginya
            // diregangkan terpisah supaya persis seperti di kertas.
            final ukuran = dasar * b.skalaLebar;
            final regang = b.skalaTinggi / b.skalaLebar;

            final teks = Text(
              t.isEmpty ? ' ' : t,
              textAlign: b.rata == 1
                  ? TextAlign.center
                  : (b.rata == 2 ? TextAlign.right : TextAlign.left),
              // Kunci pengaman: satu baris struk harus tetap satu baris.
              // Kalaupun perhitungan di atas meleset sedikit, hasilnya
              // huruf terakhir terpotong, bukan barisnya pecah dua.
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: ukuran,
                fontWeight: b.tebal ? FontWeight.w900 : FontWeight.normal,
                height: 1.25,
                color: Colors.black,
              ),
            );

            if (regang == 1) return teks;
            // Diregangkan ke bawah dari garis atas baris, sama seperti
            // printer yang menumbuhkan huruf ke bawah.
            return SizedBox(
              height: ukuran * 1.25 * regang,
              child: Transform.scale(
                scaleX: 1,
                scaleY: regang,
                alignment: Alignment.topCenter,
                child: teks,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// Struk di atas kertas putih, ukuran menyesuaikan ruang yang ada.
class KertasStrukPutih extends StatelessWidget {
  final List<BarisStruk> baris;
  final int lebar;

  const KertasStrukPutih(
      {super.key, required this.baris, required this.lebar});

  @override
  Widget build(BuildContext context) => KertasPutih(
        child: KertasStruk(baris: baris, lebar: lebar),
      );
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
                child: KertasStrukPutih(baris: baris, lebar: lebar),
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
