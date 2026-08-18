import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/db.dart';
import '../debug/kode_sumber.dart';
import '../models/models.dart';
import '../print/printer_service.dart';
import '../store/settings.dart';
import '../utils/fmt.dart';

/// Layar untuk menelusuri bug langsung dari HP, tanpa membuka laptop.
class DebugScreen extends StatelessWidget {
  const DebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Debug'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Uji Hitung'),
              Tab(text: 'Kode Logika'),
              Tab(text: 'Struk Mentah'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _TabUjiHitung(),
            _TabKode(),
            _TabStrukMentah(),
          ],
        ),
      ),
    );
  }
}

// ============================================================ uji hitung

class _TabUjiHitung extends StatefulWidget {
  const _TabUjiHitung();

  @override
  State<_TabUjiHitung> createState() => _TabUjiHitungState();
}

class _TabUjiHitungState extends State<_TabUjiHitung> {
  final _qtyCtrl = TextEditingController(text: '3.5');
  final _hargaCtrl = TextEditingController(text: '7000');

  String? _hasilAudit;
  bool _mengaudit = false;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _hargaCtrl.dispose();
    super.dispose();
  }

  /// Hitung ulang total seluruh nota dari itemnya, bandingkan dengan
  /// nilai yang tersimpan. Kalau ada selisih, berarti ada bug nyata.
  Future<void> _audit() async {
    setState(() {
      _mengaudit = true;
      _hasilAudit = null;
    });

    final daftar = await DB.instance.notaDaftar(limit: 1000);
    final masalah = <String>[];
    var diperiksa = 0;

    for (final ringkas in daftar) {
      final n = await DB.instance.notaAmbil(ringkas.id!);
      if (n == null) continue;
      diperiksa++;
      final ulang = n.hitungTotal();
      if (ulang != n.total) {
        masalah.add('${n.kode}: tersimpan ${rupiah(n.total)}, '
            'hitung ulang ${rupiah(ulang)}, selisih ${rupiah(ulang - n.total)}');
      }
      for (final it in n.items) {
        final sub = (it.qty * it.harga).round();
        if (sub != it.subtotal) {
          masalah.add('${n.kode} / ${it.nama}: subtotal tersimpan '
              '${it.subtotal}, seharusnya $sub');
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _mengaudit = false;
      _hasilAudit = masalah.isEmpty
          ? '$diperiksa nota diperiksa. Semua total cocok dengan itemnya.'
          : '$diperiksa nota diperiksa. Ditemukan ${masalah.length} '
              'ketidakcocokan:\n\n${masalah.join('\n')}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final qty = double.tryParse(_qtyCtrl.text.replaceAll(',', '.')) ?? 0;
    final harga = int.tryParse(_hargaCtrl.text.trim()) ?? 0;
    final mentah = qty * harga;
    final subtotal = mentah.round();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Subtotal satu item',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text(
          'Ubah angkanya, hasil tiap langkah muncul langsung. '
          'Ini memakai rumus yang sama persis dengan yang dipakai aplikasi.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _qtyCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'qty (double)'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _hargaCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'harga (int)'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _kotakKode('''qty      = $qty
harga    = $harga
qty * harga        = $mentah
.round()           = $subtotal
rupiah(\$subtotal)  = ${rupiah(subtotal)}

qtyStr(qty)        = ${qtyStr(qty)}'''),
        const SizedBox(height: 8),
        const Text(
          'Perhatikan baris .round(). Pembulatan terjadi di sini, jadi '
          'selisih satu rupiah pada berat desimal berasal dari langkah ini.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),

        const Divider(height: 40),

        const Text('Audit seluruh nota',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text(
          'Membaca semua nota dari database, menghitung ulang totalnya dari '
          'item, lalu membandingkan dengan angka yang tersimpan. Kalau ada '
          'selisih, berarti ada bug nyata dan bukan salah baca.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _mengaudit ? null : _audit,
          icon: const Icon(Icons.fact_check_outlined),
          label: Text(_mengaudit ? 'Memeriksa...' : 'Jalankan Audit'),
        ),
        if (_hasilAudit != null) ...[
          const SizedBox(height: 12),
          _kotakKode(_hasilAudit!),
        ],
        const SizedBox(height: 40),
      ],
    );
  }
}

// ================================================================== kode

class _TabKode extends StatelessWidget {
  const _TabKode();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Salinan logika inti aplikasi. Perlu diingat ini SALINAN teks, '
          'bukan kode yang benar-benar berjalan. Kalau Anda mengubah logika '
          'di laptop, perbarui juga lib/debug/kode_sumber.dart supaya tidak '
          'menyesatkan saat debug.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        ...KodeSumber.daftar.map(
          (p) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              title: Text(p.judul,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text(p.berkas,
                  style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Colors.grey)),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(p.catatan,
                      style: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(height: 10),
                _kotakKode(p.kode),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: p.kode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Kode disalin.')),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Salin'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

// ========================================================== struk mentah

class _TabStrukMentah extends StatefulWidget {
  const _TabStrukMentah();

  @override
  State<_TabStrukMentah> createState() => _TabStrukMentahState();
}

class _TabStrukMentahState extends State<_TabStrukMentah> {
  Nota? _nota;
  bool _memuat = true;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final daftar = await DB.instance.notaDaftar(limit: 1);
    Nota? n;
    if (daftar.isNotEmpty) n = await DB.instance.notaAmbil(daftar.first.id!);
    n ??= notaContoh();
    if (!mounted) return;
    setState(() {
      _nota = n;
      _memuat = false;
    });
  }

  String _hex(List<int> bytes) {
    final buf = StringBuffer();
    for (var i = 0; i < bytes.length; i += 16) {
      final akhir = (i + 16 > bytes.length) ? bytes.length : i + 16;
      final potong = bytes.sublist(i, akhir);
      final hex = potong
          .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join(' ');
      final teks = potong
          .map((b) => (b >= 32 && b < 127) ? String.fromCharCode(b) : '.')
          .join();
      buf.writeln('${i.toRadixString(16).padLeft(4, '0')}  '
          '${hex.padRight(47)}  $teks');
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (_memuat) return const Center(child: CircularProgressIndicator());

    final n = _nota!;
    final s = Settings.instance;
    final svc = PrinterService.instance;
    final teks = svc.susunTeks(n);
    final bytes = svc.susunBytes(n);
    final jejak = svc.jejakTerakhir;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Nota: ${n.kode}  -  ${n.pelanggan}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(
          '${s.jumlahSalinan} salinan  -  lebar ${s.lebarKertas} karakter  -  '
          '${bytes.length} byte',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        const Text(
          'Nota terbaru dipakai sebagai contoh. Kalau belum ada nota sama '
          'sekali, dipakai data contoh.',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),

        const SizedBox(height: 20),
        const Text('Hasil render template',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _kotakKode(teks),

        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(
              child: Text('Byte ESC/POS',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _hex(bytes)));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Hex dump disalin.')),
                );
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Salin'),
            ),
          ],
        ),
        const Text(
          'Persis inilah yang dikirim ke printer. Kolom kanan adalah teks '
          'yang bisa dibaca, titik berarti byte perintah.',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: _kotakKode(_hex(bytes), kecil: true),
        ),

        const SizedBox(height: 20),
        const Text('Percetakan terakhir',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _kotakKode(jejak == null
            ? 'Belum ada percetakan sejak aplikasi dibuka.'
            : 'Waktu   : ${jejak.waktu}\n'
                'Nota    : ${jejak.kodeNota}\n'
                'Salinan : ${jejak.jumlahSalinan}\n'
                'Byte    : ${jejak.bytes.length}\n'
                'Hasil   : ${jejak.hasil}\n'
                '\n--- rincian langkah ---\n'
                '${jejak.langkah.join('\n')}'),
        const SizedBox(height: 40),
      ],
    );
  }
}

// ============================================================== bersama

Widget _kotakKode(String teks, {bool kecil = false}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFF1E1E1E),
      borderRadius: BorderRadius.circular(8),
    ),
    child: SelectableText(
      teks,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: kecil ? 9 : 11,
        height: 1.4,
        color: const Color(0xFFD4D4D4),
      ),
    ),
  );
}
