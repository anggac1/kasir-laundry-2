import 'package:flutter/material.dart';

import '../db/db.dart';
import '../export/ekspor.dart';
import '../models/models.dart';
import '../utils/fmt.dart';

class EksporScreen extends StatefulWidget {
  const EksporScreen({super.key});

  @override
  State<EksporScreen> createState() => _EksporScreenState();
}

class _EksporScreenState extends State<EksporScreen> {
  /// 0 hari ini, 1 tujuh hari, 2 tiga puluh hari, 3 semua
  int _rentang = 1;
  bool _sibuk = false;

  List<Nota> _daftar = [];
  bool _memuat = true;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  String get _keterangan {
    switch (_rentang) {
      case 0:
        return 'Hari ini (${tanggal(DateTime.now())})';
      case 1:
        return '7 hari terakhir';
      case 2:
        return '30 hari terakhir';
      default:
        return 'Seluruh data';
    }
  }

  DateTime? get _batasAwal {
    final now = DateTime.now();
    switch (_rentang) {
      case 0:
        return DateTime(now.year, now.month, now.day);
      case 1:
        return now.subtract(const Duration(days: 7));
      case 2:
        return now.subtract(const Duration(days: 30));
      default:
        return null;
    }
  }

  Future<void> _muat() async {
    setState(() => _memuat = true);

    final semua = await DB.instance.notaDaftar(limit: 5000);
    final awal = _batasAwal;
    final tersaring = awal == null
        ? semua
        : semua
            .where((n) => n.dibuatMs >= awal.millisecondsSinceEpoch)
            .toList();

    // Ambil itemnya juga, dibutuhkan untuk lembar rincian di Excel.
    final lengkap = <Nota>[];
    for (final n in tersaring) {
      final penuh = await DB.instance.notaAmbil(n.id!);
      if (penuh != null) lengkap.add(penuh);
    }

    if (!mounted) return;
    setState(() {
      _daftar = lengkap;
      _memuat = false;
    });
  }

  void _pesan(String t, {bool galat = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(t),
        backgroundColor: galat ? Colors.red.shade700 : null,
        duration: const Duration(seconds: 5),
      ));
  }

  Future<void> _jalankan(bool pdf) async {
    if (_daftar.isEmpty) {
      _pesan('Tidak ada nota pada rentang ini.');
      return;
    }
    setState(() => _sibuk = true);

    final hasil = pdf
        ? await Ekspor.instance
            .laporanPdf(daftar: _daftar, keterangan: _keterangan)
        : await Ekspor.instance
            .laporanExcel(daftar: _daftar, keterangan: _keterangan);

    if (!mounted) return;
    setState(() => _sibuk = false);
    _pesan(hasil.pesan, galat: !hasil.sukses);
  }

  @override
  Widget build(BuildContext context) {
    final total = _daftar.fold<int>(0, (a, n) => a + n.total);
    final belum = _daftar
        .where((n) => n.statusBayar == StatusBayar.belum)
        .fold<int>(0, (a, n) => a + n.total);

    return Scaffold(
      appBar: AppBar(title: const Text('Ekspor Laporan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Rentang waktu',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _chip('Hari ini', 0),
              _chip('7 hari', 1),
              _chip('30 hari', 2),
              _chip('Semua', 3),
            ],
          ),
          const SizedBox(height: 20),

          if (_memuat)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_keterangan,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _baris('Jumlah nota', '${_daftar.length}'),
                  _baris('Total nilai', rupiah(total)),
                  _baris('Belum dibayar', rupiah(belum)),
                ],
              ),
            ),

          const SizedBox(height: 24),
          if (_sibuk) const LinearProgressIndicator(minHeight: 3),
          if (_sibuk)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Menyiapkan berkas...',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ),

          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: (_sibuk || _memuat) ? null : () => _jalankan(true),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Ekspor PDF'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: (_sibuk || _memuat) ? null : () => _jalankan(false),
            icon: const Icon(Icons.table_chart_outlined),
            label: const Text('Ekspor Excel'),
            style:
                OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),

          const SizedBox(height: 20),
          const Text(
            'Setelah berkas dibuat, menu berbagi bawaan HP akan muncul. '
            'Dari situ Anda bisa menyimpannya ke folder mana pun, mengirim '
            'lewat WhatsApp, atau memindahkannya ke Google Drive.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Excel berisi dua lembar: ringkasan per nota, dan rincian tiap '
            'item layanan supaya mudah dijumlahkan sendiri dengan rumus.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _chip(String label, int nilai) => ChoiceChip(
        label: Text(label),
        selected: _rentang == nilai,
        onSelected: _sibuk
            ? null
            : (_) {
                setState(() => _rentang = nilai);
                _muat();
              },
      );

  Widget _baris(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Text('$k: ', style: const TextStyle(fontSize: 13)),
            Text(v,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      );
}
