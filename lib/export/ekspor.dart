import 'dart:io';

import 'package:excel/excel.dart' as xls;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../store/settings.dart';
import '../utils/fmt.dart';

class HasilEkspor {
  final bool sukses;
  final String pesan;
  const HasilEkspor(this.sukses, this.pesan);
}

// Membuat laporan transaksi dalam bentuk PDF dan Excel. Berkas ditulis ke
// folder dokumen milik aplikasi sendiri, jadi tidak butuh izin penyimpanan
// apa pun, lalu dibuka lewat menu berbagi bawaan HP.
class Ekspor {
  Ekspor._();
  static final Ekspor instance = Ekspor._();

  static String _stempel(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}'
      '${d.day.toString().padLeft(2, '0')}_'
      '${d.hour.toString().padLeft(2, '0')}'
      '${d.minute.toString().padLeft(2, '0')}';

  // Publik supaya layar ekspor memakai angka yang sama persis dengan berkas.
  static int totalDari(List<Nota> daftar) =>
      daftar.fold<int>(0, (a, n) => a + n.total);

  static int totalBelumBayar(List<Nota> daftar) => daftar
      .where((n) => n.statusBayar == StatusBayar.belum)
      .fold<int>(0, (a, n) => a + n.total);

  Future<HasilEkspor> _simpanDanBagikan(
    List<int> bytes,
    String namaBerkas,
    String judulBagikan,
  ) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/$namaBerkas';
      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles([XFile(path)], text: judulBagikan);
      return HasilEkspor(true, 'Berkas dibuat: $namaBerkas');
    } catch (e) {
      return HasilEkspor(false, 'Gagal membuat berkas: $e');
    }
  }

  Future<HasilEkspor> laporanPdf({
    required List<Nota> daftar,
    required String keterangan,
  }) async {
    try {
      final s = Settings.instance;
      final doc = pw.Document();
      final sekarang = DateTime.now();

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          header: (ctx) => ctx.pageNumber == 1
              ? pw.SizedBox()
              : pw.Container(
                  alignment: pw.Alignment.centerRight,
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Text('${s.namaToko} - $keterangan',
                      style: const pw.TextStyle(fontSize: 9)),
                ),
          footer: (ctx) => pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Halaman ${ctx.pageNumber} dari ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          build: (ctx) => [
            pw.Text(s.namaToko,
                style: pw.TextStyle(
                    fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text(s.alamatToko, style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Telp: ${s.teleponToko}',
                style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 14),
            pw.Text('LAPORAN TRANSAKSI',
                style: pw.TextStyle(
                    fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.Text(keterangan, style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Dibuat ${tanggal(sekarang)} ${jam(sekarang)}',
                style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 14),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 0.5),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _ringkas('Jumlah nota', '${daftar.length}'),
                  _ringkas('Total nilai', rupiah(totalDari(daftar))),
                  _ringkas('Belum dibayar', rupiah(totalBelumBayar(daftar))),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            pw.TableHelper.fromTextArray(
              headers: const [
                'No Nota',
                'Tanggal',
                'Pelanggan',
                'Item',
                'Status',
                'Bayar',
                'Total',
              ],
              headerStyle: pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignments: {
                3: pw.Alignment.center,
                6: pw.Alignment.centerRight,
              },
              columnWidths: {
                0: const pw.FlexColumnWidth(2.2),
                1: const pw.FlexColumnWidth(2.0),
                2: const pw.FlexColumnWidth(2.6),
                3: const pw.FlexColumnWidth(0.9),
                4: const pw.FlexColumnWidth(1.5),
                5: const pw.FlexColumnWidth(1.7),
                6: const pw.FlexColumnWidth(1.8),
              },
              data: daftar
                  .map((n) => [
                        n.kode,
                        '${tanggal(n.dibuat)} ${jam(n.dibuat)}',
                        n.pelanggan,
                        '${n.items.length}',
                        StatusPesanan.label(n.status),
                        StatusBayar.label(n.statusBayar),
                        rupiah(n.total),
                      ])
                  .toList(),
            ),
            pw.SizedBox(height: 10),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('TOTAL: ${rupiah(totalDari(daftar))}',
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold)),
            ),
          ],
        ),
      );

      final bytes = await doc.save();
      return _simpanDanBagikan(
        bytes,
        'laporan_${_stempel(sekarang)}.pdf',
        'Laporan transaksi ${s.namaToko}',
      );
    } catch (e) {
      return HasilEkspor(false, 'Gagal membuat PDF: $e');
    }
  }

  static pw.Widget _ringkas(String label, String nilai) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
          pw.Text(nilai,
              style:
                  pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ],
      );

  // Satu baris ke sembarang lembar, tipe sel mengikuti tipe nilainya.
  static void _tulisBaris(xls.Sheet lembar, int baris, List<Object?> isi) {
    for (var k = 0; k < isi.length; k++) {
      final sel = lembar.cell(
          xls.CellIndex.indexByColumnRow(columnIndex: k, rowIndex: baris));
      final v = isi[k];
      if (v is int) {
        sel.value = xls.IntCellValue(v);
      } else if (v is double) {
        sel.value = xls.DoubleCellValue(v);
      } else {
        sel.value = xls.TextCellValue(v?.toString() ?? '');
      }
    }
  }

  Future<HasilEkspor> laporanExcel({
    required List<Nota> daftar,
    required String keterangan,
  }) async {
    try {
      final s = Settings.instance;
      final sekarang = DateTime.now();
      final buku = xls.Excel.createExcel();

      // Lembar 1: ringkasan per nota.
      final lembar = buku['Nota'];
      buku.setDefaultSheet('Nota');

      void tulis(int baris, List<Object?> isi) =>
          _tulisBaris(lembar, baris, isi);

      tulis(0, [s.namaToko]);
      tulis(1, ['Laporan transaksi', keterangan]);
      tulis(2, ['Dibuat', '${tanggal(sekarang)} ${jam(sekarang)}']);

      tulis(4, [
        'No Nota',
        'Tanggal',
        'Jam',
        'Pelanggan',
        'Jumlah Item',
        'Status Pesanan',
        'Status Bayar',
        'Uang Diterima',
        'Kembalian',
        'Total',
        'Catatan',
      ]);

      var baris = 5;
      for (final n in daftar) {
        tulis(baris++, [
          n.kode,
          tanggal(n.dibuat),
          jam(n.dibuat),
          n.pelanggan,
          n.items.length,
          StatusPesanan.label(n.status),
          StatusBayar.label(n.statusBayar),
          n.uangDibayar ?? '',
          n.kembalian ?? '',
          n.total,
          n.catatan,
        ]);
      }

      baris++;
      tulis(baris++, ['', '', '', '', '', '', '', '', 'TOTAL',
        totalDari(daftar)]);
      tulis(baris++, ['', '', '', '', '', '', '', '', 'BELUM DIBAYAR',
        totalBelumBayar(daftar)]);

      // Lembar 2: rincian item.
      final lembar2 = buku['Rincian Item'];
      void tulis2(int b, List<Object?> isi) => _tulisBaris(lembar2, b, isi);

      tulis2(0, [
        'No Nota',
        'Tanggal',
        'Pelanggan',
        'Layanan',
        'Satuan',
        'Qty',
        'Harga',
        'Subtotal',
      ]);

      var b2 = 1;
      for (final n in daftar) {
        for (final it in n.items) {
          tulis2(b2++, [
            n.kode,
            tanggal(n.dibuat),
            n.pelanggan,
            it.nama,
            it.satuan,
            it.qty,
            it.harga,
            it.subtotal,
          ]);
        }
      }

      final bytes = buku.encode();
      if (bytes == null) {
        return const HasilEkspor(false, 'Excel gagal dibentuk.');
      }

      return _simpanDanBagikan(
        bytes,
        'laporan_${_stempel(sekarang)}.xlsx',
        'Laporan transaksi ${s.namaToko}',
      );
    } catch (e) {
      return HasilEkspor(false, 'Gagal membuat Excel: $e');
    }
  }
}
