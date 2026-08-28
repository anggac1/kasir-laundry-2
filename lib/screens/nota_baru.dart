import 'package:flutter/material.dart';

import '../db/db.dart';
import '../models/models.dart';
import '../store/settings.dart';
import '../ui/umum.dart';
import '../utils/fmt.dart';
import 'dialog_cetak.dart';
import 'dialog_item.dart';
import 'nota_detail.dart';
import 'pilih_layanan_sheet.dart';
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
  final _uangCtrl = TextEditingController();
  final _cetakCtrl = TextEditingController();

  final List<ItemNota> _items = [];
  DateTime? _estimasi;

  // true  = nota dibuat di awal, perlu estimasi tanggal selesai.
  // false = nota dibuat di akhir saat cucian sudah selesai, estimasi tidak
  //         ada gunanya dan tidak ikut dicetak.
  bool _pakaiEstimasi = true;

  int _statusBayar = StatusBayar.belum;
  bool _menyimpan = false;

  // Kolom isian buatan pengguna. Kunci = kunci placeholder.
  final Map<String, TextEditingController> _ekstraCtrl = {};
  late List<String> _labelEkstra;

  bool get _modeEdit => widget.notaAwal != null;

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

  // Pakai aturan penjumlahan yang sama dengan struk dan database.
  int get _total => (Nota(kode: '', pelanggan: '', dibuatMs: 0, items: _items))
      .hitungTotal();

  // Kembalian hanya dihitung kalau kolom uang benar-benar diisi.
  String _uangKembalianInfo(String teks) {
    final uang = int.tryParse(teks.trim());
    if (uang == null) {
      return 'Boleh dikosongkan, baris ini tidak akan tercetak';
    }
    final kembali = uang - _total;
    if (kembali < 0) return 'Kurang ${rupiah(-kembali)}';
    return 'Kembalian ${rupiah(kembali)}';
  }

  // Satu-satunya tempat Nota dirakit dari isian form, dipakai untuk
  // pratinjau maupun simpan.
  Future<Nota> _susunNota({required bool untukSimpan}) async {
    final lama = widget.notaAwal;
    final now = DateTime.now();
    final nama = _namaCtrl.text.trim();

    final n = Nota(
      id: lama?.id,
      kode: lama?.kode ?? await DB.instance.kodeBerikutnya(now),
      pelanggan: untukSimpan
          ? nama
          : (nama.isEmpty ? '(nama belum diisi)' : nama),
      dibuatMs: lama?.dibuatMs ?? now.millisecondsSinceEpoch,
      estimasiMs: _pakaiEstimasi ? _estimasi?.millisecondsSinceEpoch : null,
      statusBayar: _statusBayar,
      dibayarMs: _statusBayar == StatusBayar.lunas
          ? (lama?.dibayarMs ?? now.millisecondsSinceEpoch)
          : null,
      // Uang tidak wajib. Kosong berarti tidak dicatat dan tidak dicetak.
      uangDibayar: int.tryParse(_uangCtrl.text.trim()),
      catatan: _catatanCtrl.text.trim(),
      // Kosong berarti ikut setelan bawaan di Pengaturan.
      jumlahCetak: int.tryParse(_cetakCtrl.text.trim()),
      ekstra: {
        // Simpan isian lama yang fieldnya sudah dihapus, supaya nota yang
        // pernah dibuat tidak kehilangan datanya.
        if (untukSimpan) ...?lama?.ekstra,
        for (final e in _ekstraCtrl.entries) e.key: e.value.text.trim(),
      },
      items: _items,
    );
    n.total = n.hitungTotal();
    return n;
  }

  Future<void> _pilihLayanan() async {
    final layanan = await DB.instance.layananSemua(hanyaAktif: true);
    if (!mounted) return;
    if (layanan.isEmpty) {
      pesan(context, 'Belum ada layanan. Tambahkan dulu di menu Daftar Layanan.');
      return;
    }
    final dipilih = await pilihLayananSheet(context, layanan);
    if (dipilih == null || !mounted) return;
    final item = await dialogQtyLayanan(context, dipilih);
    if (item == null || !mounted) return;
    setState(() => _items.add(item));
  }

  Future<void> _itemManual({ItemNota? edit}) async {
    final hasil = await dialogItemManual(context, edit: edit);
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

  Future<void> _pratinjauSaja() async {
    if (_items.isEmpty) {
      pesan(context, 'Belum ada item layanan.');
      return;
    }
    final n = await _susunNota(untukSimpan: false);
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

  bool _isianLengkap() {
    if (_namaCtrl.text.trim().isEmpty) {
      pesan(context, 'Nama pelanggan belum diisi.');
      return false;
    }
    if (_items.isEmpty) {
      pesan(context, 'Belum ada item layanan.');
      return false;
    }
    return true;
  }

  Future<Nota?> _simpan() async {
    if (!_isianLengkap()) return null;
    setState(() => _menyimpan = true);
    try {
      final nota = await _susunNota(untukSimpan: true);
      nota.id = await DB.instance.notaSimpan(nota);
      return nota;
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  // Setelah simpan: mode edit kembali ke pemanggil, mode baru pindah ke
  // detail nota yang baru dibuat.
  void _lanjutSetelahSimpan(Nota n) {
    final id = n.id;
    if (_modeEdit || id == null) {
      Navigator.pop(context, true);
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => NotaDetailScreen(notaId: id)),
    );
  }

  Future<void> _simpanSaja() async {
    final n = await _simpan();
    if (n == null || !mounted) return;
    _lanjutSetelahSimpan(n);
  }

  // Pratinjau dulu, baru cetak. Kalau pengguna menekan "Perbaiki Dulu",
  // tidak ada yang disimpan dan tidak ada kertas yang terpakai.
  // Nama yang pernah dibuang pengguna disaring di sini, bukan di database,
  // supaya notanya sendiri tetap utuh dan bisa dicari seperti biasa.
  Future<List<String>> _saranNama(String awalan) async {
    final hasil = await DB.instance.saranNama(awalan);
    final buang = Settings.instance.namaDisembunyikan
        .map((n) => n.toLowerCase())
        .toSet();
    return hasil.where((n) => !buang.contains(n.toLowerCase())).toList();
  }

  Future<void> _simpanDanCetak() async {
    if (!_isianLengkap()) return;

    final contoh = await _susunNota(untukSimpan: false);
    if (!mounted) return;
    final lanjut = await tampilkanPratinjau(context, contoh);
    if (!lanjut || !mounted) return;

    final n = await _simpan();
    if (n == null || !mounted) return;

    // Kalau printer bermasalah, dialognya menawarkan jalan ke Setelan
    // Bluetooth lalu mencetak lagi di tempat. Nota sudah tersimpan, jadi
    // apa pun hasilnya isian tidak hilang.
    await cetakDenganPemulihan(context, n);
    if (!mounted) return;
    _lanjutSetelahSimpan(n);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_modeEdit ? 'Ubah Nota' : 'Nota Baru')),
      body: ListView(
        // Ruang bawah ditambah setinggi keyboard, supaya isian terakhir dan
        // daftar saran nama tidak tertutup saat mengetik.
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        children: [
          KolomNama(
            controller: _namaCtrl,
            cariSaran: _saranNama,
            hapusSaran: (n) async {
              await Settings.instance.sembunyikanNama(n);
              if (mounted) pesan(context, 'Nama "\$n" tidak disarankan lagi.');
            },
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
            onSelectionChanged: (v) => setState(() => _pakaiEstimasi = v.first),
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
                style: TextStyle(color: _pakaiEstimasi ? null : Colors.grey),
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
                child:
                    Text('Belum ada item', style: TextStyle(color: Colors.grey)),
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
                Text(rupiah(_total.abs()),
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
          // Hanya helperText yang berubah tiap ketukan, jadi cukup bagian
          // ini saja yang dibangun ulang.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _uangCtrl,
            builder: (_, nilai, __) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _uangCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Uang diterima (opsional)',
                    prefixText: 'Rp ',
                    helperText: _uangKembalianInfo(nilai.text),
                  ),
                ),
                TombolNol(controller: _uangCtrl),
              ],
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
