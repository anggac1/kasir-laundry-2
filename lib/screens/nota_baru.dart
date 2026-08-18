import 'package:flutter/material.dart';

import '../db/db.dart';
import '../models/models.dart';
import '../print/printer_service.dart';
import '../store/settings.dart';
import '../utils/fmt.dart';
import 'nota_detail.dart';
import 'pratinjau.dart';

class NotaBaruScreen extends StatefulWidget {
  /// Bila diisi, layar ini berfungsi sebagai EDIT nota.
  final Nota? notaAwal;
  const NotaBaruScreen({super.key, this.notaAwal});

  @override
  State<NotaBaruScreen> createState() => _NotaBaruScreenState();
}

class _NotaBaruScreenState extends State<NotaBaruScreen> {
  final _namaCtrl = TextEditingController();
  final _catatanCtrl = TextEditingController();

  final List<ItemNota> _items = [];
  final _uangCtrl = TextEditingController();
  final _cetakCtrl = TextEditingController();
  DateTime? _estimasi;

  /// true  = nota dibuat di AWAL, perlu estimasi tanggal selesai.
  /// false = nota dibuat di AKHIR saat cucian sudah selesai, estimasi
  ///         tidak ada gunanya dan tidak ikut dicetak.
  bool _pakaiEstimasi = true;

  int _statusBayar = StatusBayar.belum;
  bool _menyimpan = false;

  /// Kolom isian buatan pengguna. Kunci = kunci placeholder.
  final Map<String, TextEditingController> _ekstraCtrl = {};
  late List<String> _labelEkstra;

  bool get _mode_edit => widget.notaAwal != null;

  @override
  void initState() {
    super.initState();
    _labelEkstra = Settings.instance.fieldTambahan;
    for (final label in _labelEkstra) {
      final kunci = Settings.kunciField(label);
      _ekstraCtrl[kunci] = TextEditingController(
        text: widget.notaAwal?.ekstra[kunci] ?? '',
      );
    }

    final n = widget.notaAwal;
    if (n != null) {
      _namaCtrl.text = n.pelanggan;
      _catatanCtrl.text = n.catatan;
      _estimasi = n.estimasi;
      _pakaiEstimasi = n.estimasi != null;
      _statusBayar = n.statusBayar;
      if (n.uangDibayar != null) _uangCtrl.text = n.uangDibayar.toString();
      if (n.jumlahCetak != null) _cetakCtrl.text = n.jumlahCetak.toString();
      _items.addAll(n.items.map((e) => e.salin()));
    } else {
      final st = Settings.instance;
      _pakaiEstimasi = st.pakaiEstimasi;
      _estimasi = DateTime.now().add(Duration(days: st.estimasiHari));
    }
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _catatanCtrl.dispose();
    _uangCtrl.dispose();
    _cetakCtrl.dispose();
    for (final c in _ekstraCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  int get _total => _items.fold<int>(0, (s, e) => s + e.subtotal);

  /// Kembalian hanya dihitung kalau kolom uang benar-benar diisi.
  String get _uangKembalianInfo {
    final uang = int.tryParse(_uangCtrl.text.trim());
    if (uang == null) {
      return 'Boleh dikosongkan, baris ini tidak akan tercetak';
    }
    final kembali = uang - _total;
    if (kembali < 0) return 'Kurang ${rupiah(-kembali)}';
    return 'Kembalian ${rupiah(kembali)}';
  }

  Future<void> _pilihLayanan() async {
    final layanan = await DB.instance.layananSemua(hanyaAktif: true);
    if (!mounted) return;
    if (layanan.isEmpty) {
      _pesan('Belum ada layanan. Tambahkan dulu di menu Daftar Layanan.');
      return;
    }
    final dipilih = await showModalBottomSheet<Layanan>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PilihLayananSheet(layanan: layanan),
    );
    if (dipilih == null || !mounted) return;
    await _isiQty(dipilih);
  }

  Future<void> _isiQty(Layanan l, {ItemNota? edit}) async {
    final ctrl = TextEditingController(
        text: edit != null ? qtyStr(edit.qty) : (l.satuan == Satuan.kg ? '' : '1'));
    final hargaCtrl =
        TextEditingController(text: (edit?.harga ?? l.harga).toString());

    final hasil = await showDialog<ItemNota>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.nama),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l.satuan == Satuan.kg ? 'Berat (kg)' : 'Jumlah (pcs)',
                helperText: l.satuan == Satuan.kg
                    ? 'Boleh desimal, contoh 3.5'
                    : 'Angka bulat',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: hargaCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Harga per ${l.satuan}',
                helperText: 'Bisa diubah khusus nota ini',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              final q = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0;
              final h = int.tryParse(hargaCtrl.text.trim()) ?? l.harga;
              if (q <= 0) return;
              Navigator.pop(
                ctx,
                ItemNota(
                  id: edit?.id,
                  nama: l.nama,
                  satuan: l.satuan,
                  qty: q,
                  harga: h,
                ),
              );
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (hasil == null || !mounted) return;
    setState(() {
      if (edit != null) {
        final i = _items.indexOf(edit);
        if (i >= 0) _items[i] = hasil;
      } else {
        _items.add(hasil);
      }
    });
  }

  /// Baris bebas yang tidak terikat daftar layanan.
  ///
  /// Dipakai untuk apa saja: tambah pemutih, hutang, saldo titipan,
  /// ongkos antar, potongan harga. Satuannya diketik sendiri dan boleh
  /// dikosongkan, harganya boleh minus untuk diskon atau pengurangan.
  Future<void> _itemManual({ItemNota? edit}) async {
    final namaCtrl = TextEditingController(text: edit?.nama ?? '');
    final qtyCtrl =
        TextEditingController(text: edit == null ? '1' : qtyStr(edit.qty));
    final satuanCtrl = TextEditingController(text: edit?.satuan ?? '');
    final hargaCtrl =
        TextEditingController(text: edit == null ? '' : edit.harga.toString());

    final hasil = await showDialog<ItemNota>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(edit == null ? 'Item Manual' : 'Ubah Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: namaCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama',
                  hintText: 'Tambah Pemutih / Hutang / Saldo',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(labelText: 'Jumlah'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: satuanCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Satuan',
                        hintText: 'botol, paket',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Satuan boleh dikosongkan, misalnya untuk hutang atau saldo.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: hargaCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(signed: true),
                decoration: const InputDecoration(
                  labelText: 'Harga satuan',
                  prefixText: 'Rp ',
                  helperText: 'Boleh minus untuk potongan, contoh -5000',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              final nama = namaCtrl.text.trim();
              final q = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 0;
              final h = int.tryParse(hargaCtrl.text.trim()) ?? 0;
              if (nama.isEmpty || q == 0) return;
              Navigator.pop(
                ctx,
                ItemNota(
                  id: edit?.id,
                  nama: nama,
                  satuan: satuanCtrl.text.trim(),
                  qty: q,
                  harga: h,
                ),
              );
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (hasil == null || !mounted) return;
    setState(() {
      if (edit != null) {
        final i = _items.indexOf(edit);
        if (i >= 0) _items[i] = hasil;
      } else {
        _items.add(hasil);
      }
    });
  }

  /// Nota versi sementara dari isian form, tanpa menyimpan ke database.
  /// Dipakai untuk pratinjau supaya kesalahan input ketahuan lebih dulu.
  Future<Nota> _notaSementara() async {
    final lama = widget.notaAwal;
    final now = DateTime.now();
    final n = Nota(
      id: lama?.id,
      kode: lama?.kode ?? await DB.instance.kodeBerikutnya(now),
      pelanggan: _namaCtrl.text.trim().isEmpty
          ? '(nama belum diisi)'
          : _namaCtrl.text.trim(),
      dibuatMs: lama?.dibuatMs ?? now.millisecondsSinceEpoch,
      estimasiMs:
          _pakaiEstimasi ? _estimasi?.millisecondsSinceEpoch : null,
      status: lama?.status ?? StatusPesanan.diterima,
      statusBayar: _statusBayar,
      uangDibayar: int.tryParse(_uangCtrl.text.trim()),
      catatan: _catatanCtrl.text.trim(),
      jumlahCetak: int.tryParse(_cetakCtrl.text.trim()),
      ekstra: {
        for (final e in _ekstraCtrl.entries) e.key: e.value.text.trim(),
      },
      items: _items,
    );
    n.total = n.hitungTotal();
    return n;
  }

  Future<void> _pratinjauSaja() async {
    if (_items.isEmpty) {
      _pesan('Belum ada item layanan.');
      return;
    }
    final n = await _notaSementara();
    if (!mounted) return;
    await tampilkanPratinjau(context, n, bisaCetak: false);
  }

  Future<void> _pilihTanggal() async {
    final kini = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _estimasi ?? kini,
      firstDate: DateTime(kini.year - 1),
      lastDate: DateTime(kini.year + 2),
    );
    if (d != null && mounted) setState(() => _estimasi = d);
  }

  void _pesan(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s)));
  }

  Future<Nota?> _simpan() async {
    if (_namaCtrl.text.trim().isEmpty) {
      _pesan('Nama pelanggan belum diisi.');
      return null;
    }
    if (_items.isEmpty) {
      _pesan('Belum ada item layanan.');
      return null;
    }
    setState(() => _menyimpan = true);

    final lama = widget.notaAwal;
    final now = DateTime.now();
    final nota = Nota(
      id: lama?.id,
      kode: lama?.kode ?? await DB.instance.kodeBerikutnya(now),
      pelanggan: _namaCtrl.text.trim(),
      // Timestamp diambil dari jam perangkat.
      dibuatMs: lama?.dibuatMs ?? now.millisecondsSinceEpoch,
      estimasiMs:
          _pakaiEstimasi ? _estimasi?.millisecondsSinceEpoch : null,
      status: lama?.status ?? StatusPesanan.diterima,
      statusBayar: _statusBayar,
      dibayarMs: _statusBayar == StatusBayar.lunas
          ? (lama?.dibayarMs ?? now.millisecondsSinceEpoch)
          : null,
      // Uang tidak wajib. Kosong berarti tidak dicatat dan tidak dicetak.
      uangDibayar: int.tryParse(_uangCtrl.text.trim()),
      // Kosong berarti ikut setelan bawaan di Pengaturan.
      jumlahCetak: int.tryParse(_cetakCtrl.text.trim()),
      catatan: _catatanCtrl.text.trim(),
      ekstra: {
        // Simpan isian lama yang fieldnya sudah dihapus, supaya nota
        // yang pernah dibuat tidak kehilangan datanya.
        ...?lama?.ekstra,
        for (final e in _ekstraCtrl.entries) e.key: e.value.text.trim(),
      },
      items: _items,
    );
    final id = await DB.instance.notaSimpan(nota);
    nota.id = id;
    if (mounted) setState(() => _menyimpan = false);
    return nota;
  }

  Future<void> _simpanSaja() async {
    final n = await _simpan();
    if (n == null || !mounted) return;
    if (_mode_edit) {
      Navigator.pop(context, true);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => NotaDetailScreen(notaId: n.id!)),
      );
    }
  }

  /// Pratinjau dulu, baru cetak. Kalau pengguna menekan "Perbaiki Dulu",
  /// tidak ada yang disimpan dan tidak ada kertas yang terpakai.
  Future<void> _simpanDanCetak() async {
    if (_namaCtrl.text.trim().isEmpty) {
      _pesan('Nama pelanggan belum diisi.');
      return;
    }
    if (_items.isEmpty) {
      _pesan('Belum ada item layanan.');
      return;
    }

    final contoh = await _notaSementara();
    if (!mounted) return;
    final lanjut = await tampilkanPratinjau(context, contoh);
    if (!lanjut || !mounted) return;

    final n = await _simpan();
    if (n == null || !mounted) return;
    final hasil = await PrinterService.instance.cetakNota(n);
    if (!mounted) return;
    _pesan(hasil.pesan);
    if (_mode_edit) {
      Navigator.pop(context, true);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => NotaDetailScreen(notaId: n.id!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_mode_edit ? 'Ubah Nota' : 'Nota Baru')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _namaCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nama pelanggan',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Kapan nota ini dibuat?',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                label: Text('Di awal'),
                icon: Icon(Icons.login),
              ),
              ButtonSegment(
                value: false,
                label: Text('Di akhir'),
                icon: Icon(Icons.check_circle_outline),
              ),
            ],
            selected: {_pakaiEstimasi},
            onSelectionChanged: (v) =>
                setState(() => _pakaiEstimasi = v.first),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _pakaiEstimasi
                  ? 'Nota dibuat saat cucian diterima, jadi perlu tanggal '
                      'perkiraan selesai.'
                  : 'Nota dibuat saat cucian sudah bersih dan langsung '
                      'diambil. Baris estimasi tidak ikut tercetak.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),

          const SizedBox(height: 12),
          InkWell(
            onTap: _pakaiEstimasi ? _pilihTanggal : null,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Estimasi selesai',
                prefixIcon: const Icon(Icons.event_outlined),
                enabled: _pakaiEstimasi,
              ),
              child: Text(
                _pakaiEstimasi
                    ? (_estimasi == null ? '-' : tanggal(_estimasi!))
                    : 'Tidak dipakai',
                style: TextStyle(
                    color: _pakaiEstimasi ? null : Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text('Item Layanan',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _itemManual(),
                icon: const Icon(Icons.edit_note),
                label: const Text('Manual'),
              ),
              TextButton.icon(
                onPressed: _pilihLayanan,
                icon: const Icon(Icons.add),
                label: const Text('Daftar'),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(
              'Daftar mengambil dari layanan tersimpan. Manual untuk baris '
              'bebas seperti tambah pemutih, hutang, atau saldo titipan.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Belum ada item',
                    style: TextStyle(color: Colors.grey)),
              ),
            ),
          ..._items.map(_kartuItem),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(_total < 0 ? 'SISA SALDO' : 'TOTAL',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(rupiah(_total < 0 ? -_total : _total),
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _total < 0 ? Colors.green.shade700 : null)),
              ],
            ),
          ),
          if (_total < 0)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Titipan pelanggan lebih besar daripada layanan yang dipakai, '
                'jadi masih ada sisa saldo.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          const SizedBox(height: 16),
          const Text('Status Pembayaran',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: StatusBayar.belum, label: Text('Belum')),
              ButtonSegment(value: StatusBayar.lunas, label: Text('Lunas')),
              ButtonSegment(
                  value: StatusBayar.sembunyi, label: Text('Sembunyi')),
            ],
            selected: {_statusBayar},
            onSelectionChanged: (v) => setState(() => _statusBayar = v.first),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Pilih Sembunyi kalau baris pembayaran tidak perlu tercetak '
              'di struk. Statusnya bisa diubah kapan saja lewat halaman '
              'detail nota, tanpa perlu mencetak ulang.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),

          const SizedBox(height: 16),
          TextField(
            controller: _uangCtrl,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Uang diterima (opsional)',
              prefixText: 'Rp ',
              helperText: _uangKembalianInfo,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _catatanCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Catatan (opsional)',
              alignLabelWithHint: true,
            ),
          ),

          // Kolom buatan sendiri, diatur di Pengaturan > Field Tambahan.
          for (final label in _labelEkstra) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _ekstraCtrl[Settings.kunciField(label)],
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: label,
                helperText: '{${Settings.kunciField(label)}}',
                helperStyle: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _cetakCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Jumlah lembar dicetak',
              prefixIcon: const Icon(Icons.copy_all_outlined),
              hintText: '${Settings.instance.jumlahSalinan}',
              helperText: 'Kosongkan untuk ikut bawaan '
                  '(${Settings.instance.jumlahSalinan} lembar)',
            ),
          ),

          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _menyimpan ? null : _simpanDanCetak,
            icon: const Icon(Icons.print_outlined),
            label: const Text('Pratinjau & Cetak'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _menyimpan ? null : _pratinjauSaja,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Pratinjau'),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _menyimpan ? null : _simpanSaja,
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48)),
                  child: const Text('Simpan Saja'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _kartuItem(ItemNota it) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(it.nama),
        subtitle: Text('${Satuan.gabung(qtyStr(it.qty), it.satuan)}'
            ' x ${rupiah(it.harga)}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(rupiah(it.subtotal),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => setState(() => _items.remove(it)),
            ),
          ],
        ),
        // Editor manual dipakai untuk semua item, supaya nama, satuan,
        // jumlah, dan harga bisa dibetulkan sekaligus.
        onTap: () => _itemManual(edit: it),
      ),
    );
  }
}

class _PilihLayananSheet extends StatefulWidget {
  final List<Layanan> layanan;
  const _PilihLayananSheet({required this.layanan});

  @override
  State<_PilihLayananSheet> createState() => _PilihLayananSheetState();
}

class _PilihLayananSheetState extends State<_PilihLayananSheet> {
  String _cari = '';

  @override
  Widget build(BuildContext context) {
    final data = widget.layanan
        .where((l) => l.nama.toLowerCase().contains(_cari.toLowerCase()))
        .toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (_, controller) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              autofocus: false,
              onChanged: (v) => setState(() => _cari = v),
              decoration: const InputDecoration(
                hintText: 'Cari layanan',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: controller,
              itemCount: data.length,
              itemBuilder: (_, i) {
                final l = data[i];
                return ListTile(
                  leading: CircleAvatar(
                    child: Icon(l.satuan == Satuan.kg
                        ? Icons.scale_outlined
                        : Icons.checkroom_outlined),
                  ),
                  title: Text(l.nama),
                  subtitle: Text('${rupiah(l.harga)} / ${l.satuan}'),
                  onTap: () => Navigator.pop(context, l),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
