import 'dart:async';

import 'package:flutter/material.dart';

import '../db/db.dart';
import '../models/models.dart';
import '../store/settings.dart';
import '../utils/fmt.dart';
import 'layanan.dart';
import 'nota_baru.dart';
import 'nota_detail.dart';
import 'panduan.dart';
import 'pengaturan.dart';
import 'template_editor.dart';

class BerandaScreen extends StatefulWidget {
  const BerandaScreen({super.key});

  @override
  State<BerandaScreen> createState() => _BerandaScreenState();
}

class _BerandaScreenState extends State<BerandaScreen> {
  final _cariCtrl = TextEditingController();
  Timer? _jedaCari;

  List<Nota> _notas = [];
  Map<String, int> _ringkasan = {};
  bool _memuat = true;

  bool _hanyaHutang = false;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _jedaCari?.cancel();
    _cariCtrl.dispose();
    super.dispose();
  }

  // Query ditunda agar mengetik cepat tidak menembak DB tiap huruf, tapi
  // setState langsung dipanggil supaya tombol hapus teks tidak telat muncul.
  void _cariBerubah() {
    setState(() {});
    _jedaCari?.cancel();
    _jedaCari = Timer(const Duration(milliseconds: 300), _muat);
  }

  Future<void> _muat({bool paksaRingkasan = false}) async {
    if (!mounted) return;
    setState(() => _memuat = true);
    // Dijalankan bersamaan, bukan bergantian: keduanya tidak saling
    // membutuhkan, jadi menunggunya satu per satu hanya menunda tampilan.
    final hasil = await Future.wait([
      DB.instance.notaDaftar(belumLunas: _hanyaHutang, cari: _cariCtrl.text),
      DB.instance.ringkasanHariIni(paksa: paksaRingkasan),
    ]);
    if (!mounted) return;
    setState(() {
      _notas = hasil[0] as List<Nota>;
      _ringkasan = hasil[1] as Map<String, int>;
      _memuat = false;
    });
  }

  Future<void> _buka(Widget layar) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => layar));
    await _muat();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasir Laundry'),
        actions: [
          // Hanya muncul pada mode manual. Titik menandakan angkanya sudah
          // berubah sejak terakhir dihitung.
          if (!Settings.instance.hutangOtomatis)
            IconButton(
              tooltip: 'Perbarui angka hutang',
              onPressed: _memuat ? null : () => _muat(paksaRingkasan: true),
              icon: Badge(
                isLabelVisible: DB.instance.ringkasanPerluDiperbarui,
                smallSize: 8,
                child: const Icon(Icons.refresh),
              ),
            ),
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'layanan':
                  _buka(const LayananScreen());
                  break;
                case 'template':
                  _buka(const TemplateEditorScreen());
                  break;
                case 'pengaturan':
                  _buka(const PengaturanScreen());
                  break;
                case 'panduan':
                  _buka(const PanduanScreen());
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'layanan',
                child: ListTile(
                  leading: Icon(Icons.local_offer_outlined),
                  title: Text('Daftar Layanan'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'template',
                child: ListTile(
                  leading: Icon(Icons.receipt_long_outlined),
                  title: Text('Template Struk'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'pengaturan',
                child: ListTile(
                  leading: Icon(Icons.settings_outlined),
                  title: Text('Pengaturan'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'panduan',
                child: ListTile(
                  leading: Icon(Icons.help_outline),
                  title: Text('Panduan'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _buka(const NotaBaruScreen()),
        icon: const Icon(Icons.add),
        label: const Text('Nota Baru'),
      ),
      body: RefreshIndicator(
        onRefresh: _muat,
        child: Column(
          children: [
            _kartuRingkasan(),
            _barisFilter(),
            const Divider(height: 1),
            Expanded(
              child: _memuat
                  ? const Center(child: CircularProgressIndicator())
                  : _notas.isEmpty
                      ? _kosong()
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 88),
                          itemCount: _notas.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 16),
                          itemBuilder: (_, i) => _baris(_notas[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kartuRingkasan() {
    Widget kotak(String judul, String nilai, IconData ikon, Color warna) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: warna.withAlpha(26),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(ikon, size: 18, color: warna),
              const SizedBox(height: 6),
              Text(nilai,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: warna)),
              Text(judul,
                  style: const TextStyle(fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          kotak('Belum dibayar', rupiah(_ringkasan['belumLunasNilai'] ?? 0),
              Icons.account_balance_wallet_outlined, Colors.red.shade700),
          const SizedBox(width: 8),
          kotak('Nota berhutang', '${_ringkasan['belumLunasJml'] ?? 0} nota',
              Icons.error_outline, Colors.orange.shade800),
        ],
      ),
    );
  }

  Widget _barisFilter() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _cariCtrl,
            onChanged: (_) => _cariBerubah(),
            decoration: InputDecoration(
              hintText: 'Cari nama pelanggan atau nomor nota',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _cariCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _jedaCari?.cancel();
                        _cariCtrl.clear();
                        _muat();
                      },
                    ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: FilterChip(
              label: const Text('Belum lunas'),
              selected: _hanyaHutang,
              onSelected: (v) {
                setState(() => _hanyaHutang = v);
                _muat();
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _kosong() {
    return ListView(
      children: const [
        SizedBox(height: 80),
        Icon(Icons.local_laundry_service_outlined, size: 64, color: Colors.grey),
        SizedBox(height: 12),
        Center(
          child: Text(
            'Belum ada nota.\nTekan tombol Nota Baru untuk mulai.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _baris(Nota n) {
    final id = n.id;
    return ListTile(
      onTap: id == null ? null : () => _buka(NotaDetailScreen(notaId: id)),
      title: Text(n.pelanggan,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${n.kode}  -  ${tanggal(n.dibuat)} ${jam(n.dibuat)}'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(rupiah(n.nilaiTampil),
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: n.adaSisaSaldo ? Colors.green.shade700 : null)),
          if (n.adaSisaSaldo)
            Text('sisa saldo',
                style: TextStyle(
                    fontSize: 10, color: Colors.green.shade700)),
          const SizedBox(height: 4),
          LencanaBayar(statusBayar: n.statusBayar),
        ],
      ),
      isThreeLine: false,
    );
  }
}

// Lencana kecil untuk status pembayaran.
class LencanaBayar extends StatelessWidget {
  final int statusBayar;
  const LencanaBayar({super.key, required this.statusBayar});

  @override
  Widget build(BuildContext context) {
    if (statusBayar == StatusBayar.sembunyi) {
      return const SizedBox.shrink();
    }
    final lunas = statusBayar == StatusBayar.lunas;
    return _pil(lunas ? 'LUNAS' : 'BELUM BAYAR',
        lunas ? Colors.green.shade700 : Colors.red.shade700);
  }
}

Widget _pil(String teks, Color warna) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: warna.withAlpha(31),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(teks,
          style: TextStyle(
              fontSize: 10, color: warna, fontWeight: FontWeight.w700)),
    );
