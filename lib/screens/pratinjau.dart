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

  const KertasStruk({super.key, required this.baris, required this.lebar});

  @override
  Widget build(BuildContext context) {
    // Struk digambar pada ukuran TETAP, lalu SELURUHNYA dikecilkan oleh
    // FittedBox sampai pas selebar ruang yang ada.
    //
    // Cara sebelumnya mencari ukuran huruf yang "kira-kira muat", dan itu
    // terus meleset: lebar teks tidak tumbuh lurus mengikuti ukuran huruf,
    // jadi berapa pun ukuran yang diperiksa, hasil gambar sungguhannya
    // masih bisa lebih lebar. FittedBox tidak menebak sama sekali - ia
    // mengukur hasil jadinya lalu mengecilkan seperlunya, jadi mustahil
    // ada yang terpotong.
    const dasar = 16.0;

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...baris.map((b) {
            final efektif = Struk.lebarEfektif(lebar, b.skalaLebar);
            var t = b.teks;

            // TIDAK dipotong di sini.
            //
            // Baris yang masuk ke sini sudah dipatahkan per kata oleh
            // _bungkus() sewaktu disusun, jadi panjangnya pasti sudah
            // muat. Pemotongan tambahan di layar hanya bisa merusak:
            // baris 34 karakter pada kertas 32 terpangkas jadi
            // "Total          Rp60.0" - itulah "Rp60.000" yang hilang
            // ekornya. Kalau toh ada yang lebih panjang, biar FittedBox
            // yang mengecilkan seluruhnya, bukan huruf yang dibuang.

            // Perataan dikerjakan dengan SPASI, bukan dengan lebar kotak.
            //
            // Sebelumnya tiap baris dipaksa selebar kertas lewat
            // SizedBox. Baris yang ternyata sedikit lebih lebar dipotong
            // DI DALAM kotak itu, sehingga FittedBox tidak pernah melihat
            // ada yang kelebihan dan tidak pernah mengecilkan.
            //
            // Dengan spasi, tiap baris selebar isinya sendiri, dan
            // FittedBox bisa melihat baris terlebar lalu mengecilkan
            // semuanya.
            //
            // Patokannya [efektif], BUKAN lebar kertas penuh.
            //
            // Struk.pratinjau() memakai lebar penuh karena hasilnya teks
            // polos yang tidak punya ukuran huruf: di sana [B2] harus
            // ditambal jadi 32 karakter supaya terlihat selebar kertas.
            // Di layar hurufnya memang benar-benar dua kali lebar, jadi
            // 16 karakter sudah memenuhi 32 kolom. Menambalnya sampai 32
            // karakter membuat barisnya dua kali lebar kertas, dan
            // FittedBox akan mengecilkan SELURUH struk jadi separuh.
            // Angkanya beda supaya hasil gambarnya sama.
            if (t.length < efektif) {
              final sisa = efektif - t.length;
              if (b.rata == 1) {
                final kiri = sisa ~/ 2;
                t = ' ' * kiri + t + ' ' * (sisa - kiri);
              } else if (b.rata == 2) {
                t = ' ' * sisa + t;
              } else {
                t = t + ' ' * sisa;
              }
            }

            // Lebar dan tinggi bisa berbeda, misalnya [C1.5] yang lebar
            // 1 tinggi 2.
            final ukuran = dasar * b.skalaLebar;
            final regang = b.skalaTinggi / b.skalaLebar;

            final teks = Text(
              t.isEmpty ? ' ' : t,
              maxLines: 1,
              softWrap: false,
              // Struk tidak ikut membesar mengikuti setelan Ukuran Font
              // di HP, karena lebarnya ditentukan lebar kertas.
              textScaler: TextScaler.noScaling,
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
          }),
        ],
      ),
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
            // LayoutBuilder di dalam SingleChildScrollView bisa menerima
            // lebar tak terhingga. Dibungkus LayoutBuilder di LUAR
            // scroll-nya, lebar yang pasti itu diteruskan ke bawah,
            // sehingga penghitung ukuran huruf tidak pernah menebak.
            Flexible(
              child: LayoutBuilder(
                builder: (ctx, batas) => SingleChildScrollView(
                  child: SizedBox(
                    width: batas.maxWidth,
                    child: KertasStrukPutih(baris: baris, lebar: lebar),
                  ),
                ),
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
