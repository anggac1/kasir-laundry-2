import 'package:flutter/material.dart';

import '../db/db.dart';
import '../models/models.dart';
import '../print/printer_service.dart';
import '../print/receipt.dart';
import '../store/settings.dart';
import '../utils/fmt.dart';
import 'beranda.dart' show LencanaBayar, LencanaStatus;
import 'nota_baru.dart';
import 'pratinjau.dart';

class NotaDetailScreen extends StatefulWidget {
  final int notaId;
  const NotaDetailScreen({super.key, required this.notaId});

  @override
  State<NotaDetailScreen> createState() => _NotaDetailScreenState();
}

class _NotaDetailScreenState extends State<NotaDetailScreen> {
  Nota? _nota;
  bool _memuat = true;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final n = await DB.instance.notaAmbil(widget.notaId);
    if (!mounted) return;
    setState(() {
      _nota = n;
      _memuat = false;
    });
  }

  void _pesan(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> _ubahStatus(int status) async {
    await DB.instance.notaUbahStatus(widget.notaId, status);
    await _muat();
  }

  /// Membenarkan baris pembayaran satu nota saja, tanpa mengubah
  /// apa pun yang lain. Dipakai saat pelanggan melunasi ketika
  /// mengambil cucian.
  Future<void> _ubahBayar(int statusBayar) async {
    await DB.instance.notaUbahBayar(widget.notaId, statusBayar);
    await _muat();
    _pesan('Pembayaran diubah jadi ${StatusBayar.label(statusBayar)}.');
  }

  Future<void> _ubahUang() async {
    final n = _nota;
    if (n == null) return;
    final ctrl = TextEditingController(
        text: n.uangDibayar == null ? '' : n.uangDibayar.toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Uang Diterima'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            prefixText: 'Rp ',
            helperText: 'Kosongkan bila tidak ingin dicatat. '
                'Total ${rupiah(n.total)}',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Simpan')),
        ],
      ),
    );
    if (ok != true) return;
    await DB.instance
        .notaUbahUang(widget.notaId, int.tryParse(ctrl.text.trim()));
    await _muat();
  }

  Future<void> _ubahJumlahCetak() async {
    final n = _nota;
    if (n == null) return;
    final ctrl = TextEditingController(
        text: n.jumlahCetak == null ? '' : n.jumlahCetak.toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Jumlah Lembar'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Lembar',
            helperText: 'Kosongkan untuk ikut bawaan '
                '(${Settings.instance.jumlahSalinan} lembar)',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Simpan')),
        ],
      ),
    );
    if (ok != true) return;
    final v = int.tryParse(ctrl.text.trim());
    await DB.instance.notaUbahJumlahCetak(
        widget.notaId, (v == null || v < 1) ? null : v);
    await _muat();
  }

  /// Selalu tampilkan pratinjau lebih dulu, supaya salah input
  /// ketahuan sebelum kertas terpakai.
  Future<void> _cetak() async {
    final n = _nota;
    if (n == null) return;
    final lanjut = await tampilkanPratinjau(context, n);
    if (!lanjut || !mounted) return;
    _pesan('Menghubungkan ke printer...');
    final hasil = await PrinterService.instance.cetakNota(n);
    if (!mounted) return;
    _pesan(hasil.pesan);
  }

  Future<void> _pratinjau() async {
    final n = _nota;
    if (n == null) return;
    await tampilkanPratinjau(context, n, bisaCetak: false);
  }

  Future<void> _hapus() async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus nota ini?'),
        content: const Text('Data yang dihapus tidak bisa dikembalikan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ya != true) return;
    await DB.instance.notaHapus(widget.notaId);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _ubah() async {
    final n = _nota;
    if (n == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NotaBaruScreen(notaAwal: n)),
    );
    await _muat();
  }

  @override
  Widget build(BuildContext context) {
    final n = _nota;
    return Scaffold(
      appBar: AppBar(
        title: Text(n?.kode ?? 'Nota'),
        actions: [
          IconButton(
              onPressed: n == null ? null : _pratinjau,
              icon: const Icon(Icons.visibility_outlined),
              tooltip: 'Pratinjau struk'),
          IconButton(
              onPressed: n == null ? null : _ubah,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Ubah'),
          IconButton(
              onPressed: n == null ? null : _hapus,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Hapus'),
        ],
      ),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : n == null
              ? const Center(child: Text('Nota tidak ditemukan.'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(n.pelanggan,
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('Dibuat ${tanggalJam(n.dibuat)}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                              if (n.estimasi != null)
                                Text('Estimasi ${tanggal(n.estimasi!)}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            LencanaStatus(status: n.status),
                            const SizedBox(height: 4),
                            LencanaBayar(statusBayar: n.statusBayar),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text('Status Pesanan',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: StatusPesanan.semua
                          .map((s) => ChoiceChip(
                                label: Text(StatusPesanan.label(s)),
                                selected: n.status == s,
                                onSelected: (_) => _ubahStatus(s),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                    const Text('Pembayaran',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(
                            value: StatusBayar.belum, label: Text('Belum')),
                        ButtonSegment(
                            value: StatusBayar.lunas, label: Text('Lunas')),
                        ButtonSegment(
                            value: StatusBayar.sembunyi,
                            label: Text('Sembunyi')),
                      ],
                      selected: {n.statusBayar},
                      onSelectionChanged: (v) => _ubahBayar(v.first),
                    ),
                    if (n.lunas && n.dibayarMs != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Dibayar ${tanggalJam(DateTime.fromMillisecondsSinceEpoch(n.dibayarMs!))}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.payments_outlined),
                      title: const Text('Uang diterima'),
                      subtitle: Text(n.uangDibayar == null
                          ? 'Tidak dicatat'
                          : '${rupiah(n.uangDibayar!)}'
                              '  -  kembali ${rupiah(n.kembalian ?? 0)}'),
                      trailing: const Icon(Icons.edit_outlined, size: 18),
                      onTap: _ubahUang,
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.copy_all_outlined),
                      title: const Text('Jumlah lembar dicetak'),
                      subtitle: Text(n.jumlahCetak == null
                          ? 'Ikut bawaan '
                              '(${Settings.instance.jumlahSalinan} lembar)'
                          : '${n.jumlahCetak} lembar'),
                      trailing: const Icon(Icons.edit_outlined, size: 18),
                      onTap: _ubahJumlahCetak,
                    ),
                    const SizedBox(height: 20),
                    const Text('Rincian',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...n.items.map(
                      (it) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(it.nama),
                                  Text(
                                    '${qtyStr(it.qty)} ${it.satuan} x ${rupiah(it.harga)}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Text(rupiah(it.subtotal)),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        Text(n.labelTotal,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Text(rupiah(n.nilaiTampil),
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: n.adaSisaSaldo
                                    ? Colors.green.shade700
                                    : null)),
                      ],
                    ),
                    if (n.adaSisaSaldo)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Titipan pelanggan masih lebih besar daripada '
                          'layanan yang dipakai.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    if (n.catatan.trim().isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text('Catatan',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(n.catatan),
                    ],
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: _cetak,
                      icon: const Icon(Icons.print_outlined),
                      label: const Text('Cetak Struk'),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
    );
  }
}
