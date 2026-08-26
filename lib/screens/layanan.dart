import 'package:flutter/material.dart';

import '../db/db.dart';
import '../models/models.dart';
import '../ui/umum.dart';
import '../utils/fmt.dart';

class LayananScreen extends StatefulWidget {
  const LayananScreen({super.key});

  @override
  State<LayananScreen> createState() => _LayananScreenState();
}

class _LayananScreenState extends State<LayananScreen> {
  List<Layanan> _data = [];
  bool _memuat = true;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final d = await DB.instance.layananSemua();
    if (!mounted) return;
    setState(() {
      _data = d;
      _memuat = false;
    });
  }

  Future<void> _form({Layanan? awal}) async {
    final namaCtrl = TextEditingController(text: awal?.nama ?? '');
    final hargaCtrl =
        TextEditingController(text: awal == null ? '' : awal.harga.toString());
    // Kalau satuan tersimpan bukan kg/pcs, dropdown langsung di posisi
    // "ketik sendiri" dengan teksnya sudah terisi.
    final awalBawaan = awal == null || Satuan.bawaan(awal.satuan);
    var pilihan = awalBawaan ? (awal?.satuan ?? Satuan.kg) : Satuan.lainnya;
    final satuanCtrl =
        TextEditingController(text: awalBawaan ? '' : (awal?.satuan ?? ''));
    var aktif = awal?.aktif ?? true;

    try {
      final simpan = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text(awal == null ? 'Layanan Baru' : 'Ubah Layanan'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: namaCtrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration:
                        const InputDecoration(labelText: 'Nama layanan'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: pilihan,
                    decoration: const InputDecoration(labelText: 'Satuan'),
                    items: Satuan.semuaPlusLainnya
                        .map((u) => DropdownMenuItem(
                            value: u, child: Text(Satuan.label(u))))
                        .toList(),
                    onChanged: (v) => setLocal(() => pilihan = v ?? Satuan.kg),
                  ),
                  if (pilihan == Satuan.lainnya) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: satuanCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tulis satuannya',
                        hintText: 'meter, paket, lembar',
                        helperText: 'Boleh dikosongkan kalau tanpa satuan',
                      ),
                      onChanged: (_) => setLocal(() {}),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: hargaCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: pilihan == Satuan.lainnya
                          ? (satuanCtrl.text.trim().isEmpty
                              ? 'Harga'
                              : 'Harga per ${satuanCtrl.text.trim()}')
                          : 'Harga per $pilihan',
                      prefixText: 'Rp ',
                    ),
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    value: aktif,
                    onChanged: (v) => setLocal(() => aktif = v),
                    title: const Text('Aktif'),
                    subtitle: const Text('Muncul saat membuat nota'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
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
        ),
      );

      if (simpan != true) return;
      final nama = namaCtrl.text.trim();
      final harga = int.tryParse(hargaCtrl.text.trim()) ?? 0;
      if (nama.isEmpty || harga <= 0) {
        if (mounted) pesan(context, 'Nama dan harga wajib diisi.', galat: true);
        return;
      }
      final satuanAkhir =
          pilihan == Satuan.lainnya ? satuanCtrl.text.trim() : pilihan;

      await DB.instance.layananSimpan(Layanan(
        id: awal?.id,
        nama: nama,
        satuan: satuanAkhir,
        harga: harga,
        aktif: aktif,
      ));
      await _muat();
    } finally {
      namaCtrl.dispose();
      hargaCtrl.dispose();
      satuanCtrl.dispose();
    }
  }

  Future<void> _hapus(Layanan l) async {
    final id = l.id;
    if (id == null) return;
    final ya = await konfirmasiHapus(
      context,
      judul: 'Hapus "${l.nama}"?',
      isi: 'Nota lama tidak terpengaruh, karena nama dan harga sudah '
          'tersimpan di nota masing-masing.',
    );
    if (!ya) return;
    await DB.instance.layananHapus(id);
    await _muat();
  }

  @override
  Widget build(BuildContext context) {
    final kiloan = _data.where((l) => l.satuan == Satuan.kg).toList();
    final satuan = _data.where((l) => l.satuan == Satuan.pcs).toList();
    final lainnya = _data.where((l) => !Satuan.bawaan(l.satuan)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Layanan')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _form(),
        child: const Icon(Icons.add),
      ),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                _seksi('Kiloan (per kg)', kiloan.length),
                ...kiloan.map(_baris),
                _seksi('Satuan (per pcs)', satuan.length),
                ...satuan.map(_baris),
                if (lainnya.isNotEmpty) ...[
                  _seksi('Satuan lainnya', lainnya.length),
                  ...lainnya.map(_baris),
                ],
                if (_data.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text('Belum ada layanan.',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  ),
              ],
            ),
    );
  }

  // JudulSeksi berpadding kecil, digeser agar sejajar dengan ListTile.
  Widget _seksi(String teks, int jumlah) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: JudulSeksi('$teks  ($jumlah)'),
      );

  Widget _baris(Layanan l) => ListTile(
        leading: CircleAvatar(
          child: Icon(l.satuan == Satuan.kg
              ? Icons.scale_outlined
              : (l.satuan == Satuan.pcs
                  ? Icons.checkroom_outlined
                  : Icons.category_outlined)),
        ),
        title: Text(l.nama,
            style: TextStyle(
                decoration: l.aktif ? null : TextDecoration.lineThrough)),
        subtitle: Text(
            '${rupiah(l.harga)}${l.satuan.trim().isEmpty ? '' : ' / ${l.satuan}'}'
            '${l.aktif ? '' : '  -  nonaktif'}'),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _hapus(l),
        ),
        onTap: () => _form(awal: l),
      );
}
