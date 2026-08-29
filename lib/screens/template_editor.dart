import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/db.dart';
import '../print/receipt.dart';
import '../store/settings.dart';
import 'pratinjau.dart';
import '../ui/umum.dart';

// Editor template struk. Pengguna sendiri yang menentukan mana teks tetap
// dan mana placeholder dalam kurung kurawal yang diisi otomatis dari nota.
class TemplateEditorScreen extends StatefulWidget {
  const TemplateEditorScreen({super.key});

  @override
  State<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends State<TemplateEditorScreen> {
  late TextEditingController _utama;
  late TextEditingController _item;
  final _fokusUtama = FocusNode();
  final _fokusItem = FocusNode();

  // 0 = sedang mengedit template utama, 1 = template item.
  int _aktif = 0;

  Timer? _jeda;

  @override
  void initState() {
    super.initState();
    final s = Settings.instance;
    _utama = TextEditingController(text: s.template);
    _item = TextEditingController(text: s.templateItem);
    _utama.addListener(_refresh);
    _item.addListener(_refresh);
    _fokusUtama.addListener(() {
      if (_fokusUtama.hasFocus) setState(() => _aktif = 0);
    });
    _fokusItem.addListener(() {
      if (_fokusItem.hasFocus) setState(() => _aktif = 1);
    });
  }

  // Render template penuh mahal, jadi ditunda sebentar supaya tidak
  // dijalankan ulang pada setiap ketukan tombol.
  void _refresh() {
    _jeda?.cancel();
    _jeda = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _jeda?.cancel();
    _utama.dispose();
    _item.dispose();
    _fokusUtama.dispose();
    _fokusItem.dispose();
    super.dispose();
  }

  TextEditingController get _ctrl => _aktif == 0 ? _utama : _item;

  void _sisip(String teks) {
    final c = _ctrl;
    final sel = c.selection;
    final awal = sel.isValid ? sel.start : c.text.length;
    final akhir = sel.isValid ? sel.end : c.text.length;
    final baru = c.text.replaceRange(awal, akhir, teks);
    c.value = TextEditingValue(
      text: baru,
      selection: TextSelection.collapsed(offset: awal + teks.length),
    );
  }

  Future<void> _simpan() async {
    final s = Settings.instance;
    await s.setTemplate(_utama.text);
    await s.setTemplateItem(_item.text);
    if (!mounted) return;
    pesan(context, 'Template tersimpan.');
  }

  Future<void> _reset() async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kembalikan template bawaan?'),
        content: const Text('Semua perubahan teks Anda akan hilang.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Kembalikan')),
        ],
      ),
    );
    if (ya != true) return;
    await Settings.instance.resetTemplate();
    if (!mounted) return;
    setState(() {
      _utama.text = kTemplateBawaan;
      _item.text = kTemplateItemBawaan;
    });
  }

  // Lima laci simpanan. Membuka lembar ini tidak mengubah apa pun sampai
  // pengguna menekan Simpan atau Pakai di salah satu barisnya.
  Future<void> _laci() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLembar) {
          final s = Settings.instance;
          final nama = s.namaSimpanan;
          return SafeArea(
            child: Padding(
              // Papan ketik tidak boleh menutupi baris paling bawah.
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text('Template Tersimpan',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      'Lima laci untuk menyimpan template yang sudah jadi. '
                      'Simpan menaruh template yang sedang dibuka ke laci; '
                      'Pakai menimpa yang sedang dibuka dengan isi laci.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const Divider(height: 1),
                  for (var i = 0; i < Settings.kMaksSimpanan; i++)
                    ListTile(
                      leading: CircleAvatar(
                        radius: 14,
                        child: Text('${i + 1}',
                            style: const TextStyle(fontSize: 12)),
                      ),
                      title: Text(
                        s.laciTerisi(i) ? nama[i] : 'Laci ${i + 1} kosong',
                        style: TextStyle(
                          fontSize: 14,
                          color: s.laciTerisi(i) ? null : Colors.grey.shade600,
                          fontStyle: s.laciTerisi(i)
                              ? FontStyle.normal
                              : FontStyle.italic,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (s.laciTerisi(i)) ...[
                            TextButton(
                              onPressed: () async {
                                await _pakaiLaci(i, nama[i]);
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                              child: const Text('Pakai'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              tooltip: 'Kosongkan laci',
                              color: Theme.of(ctx).colorScheme.error,
                              onPressed: () async {
                                await _hapusLaci(i, nama[i]);
                                setLembar(() {});
                              },
                            ),
                          ] else
                            const SizedBox(width: 8),
                          TextButton(
                            onPressed: () async {
                              await _simpanKeLaci(i, nama[i]);
                              setLembar(() {});
                            },
                            child: Text(s.laciTerisi(i) ? 'Timpa' : 'Simpan'),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // #Menaruh template yang sedang dibuka ke laci, setelah diberi nama
  Future<void> _simpanKeLaci(int i, String namaLama) async {
    final nama = await dialogIsian(
      context,
      judul: 'Simpan ke laci ${i + 1}',
      awal: namaLama.isEmpty ? '' : namaLama,
      label: 'Nama template',
      bantuan: 'Misalnya: Struk 58mm, atau Versi hemat kertas',
    );
    if (nama == null) return;
    // Yang disimpan adalah isi kotak teks, bukan yang tersimpan di
    // pengaturan, supaya perubahan yang belum ditekan Simpan ikut terbawa.
    final s = Settings.instance;
    await s.setTemplate(_utama.text);
    await s.setTemplateItem(_item.text);
    await s.simpanKeLaci(i, nama);
    if (!mounted) return;
    pesan(context, 'Tersimpan ke laci ${i + 1}.');
  }

  // #Menimpa template yang sedang dibuka dengan isi laci
  Future<void> _pakaiLaci(int i, String nama) async {
    final ya = await konfirmasiHapus(
      context,
      judul: 'Pakai "$nama"?',
      isi: 'Template yang sedang dibuka akan ditimpa. Kalau belum '
          'tersimpan di laci lain, isinya hilang.',
      tombol: 'Pakai',
    );
    if (!ya) return;
    await Settings.instance.muatDariLaci(i);
    if (!mounted) return;
    setState(() {
      _utama.text = Settings.instance.template;
      _item.text = Settings.instance.templateItem;
    });
    _refresh();
    pesan(context, 'Template "$nama" dipakai.');
  }

  // #Mengosongkan laci
  Future<void> _hapusLaci(int i, String nama) async {
    final ya = await konfirmasiHapus(
      context,
      judul: 'Kosongkan laci ${i + 1}?',
      isi: 'Template "$nama" dihapus dari laci. Yang sedang dibuka '
          'tidak ikut berubah.',
    );
    if (!ya) return;
    await Settings.instance.hapusLaci(i);
    if (!mounted) return;
    pesan(context, 'Laci ${i + 1} dikosongkan.');
  }

  void _bantuan() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cara Pakai'),
        content: const SingleChildScrollView(
          child: Text(
            'TEKS FLAT\n'
            'Semua yang Anda ketik biasa akan dicetak persis seperti itu di '
            'setiap struk. Cocok untuk nama laundry, alamat, syarat & '
            'ketentuan, dan ucapan terima kasih.\n\n'
            'TEKS BERUBAH\n'
            'Tulisan di dalam kurung kurawal akan diganti otomatis sesuai isi '
            'nota. Contoh {nama_pelanggan} akan berubah jadi nama pelanggan '
            'pada nota tersebut. Tekan tombol placeholder di bawah untuk '
            'menyisipkannya.\n\n'
            'TAG PERATAAN (ditulis di awal baris)\n'
            '[C]  rata tengah\n'
            '[R]  rata kanan\n'
            '[L]  rata kiri (bawaan)\n'
            '[B]  huruf tebal\n'
            '[H]  huruf besar dobel\n'
            'Boleh digabung, contoh [B][C] atau [BC].\n\n'
            'TAG KHUSUS\n'
            '[>]  dorong sisa teks ke pinggir kanan.\n'
            '     Contoh: TOTAL[>]{total}\n'
            '---  membuat garis pemisah selebar kertas.\n'
            '     Bisa juga === atau ***\n\n'
            'DAFTAR ITEM\n'
            'Baris berisi {daftar_item} akan diganti dengan seluruh item '
            'pada nota. Bentuk tiap barisnya diatur di tab Baris Item.\n\n'
            'Teks yang terlalu panjang akan dipotong otomatis ke baris '
            'berikutnya agar muat di lebar kertas.',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        ],
      ),
    );
  }

  // Placeholder bawaan ditambah field buatan pengguna.
  Map<String, String> get _placeholderUtama {
    final m = Map<String, String>.from(Struk.placeholderNota);
    for (final label in Settings.instance.fieldTambahan) {
      m['{${Settings.kunciField(label)}}'] = 'Field tambahan: $label';
    }
    return m;
  }

  // Pratinjau memakai teks yang sedang diketik, bukan yang sudah tersimpan.
  //
  // Hasilnya berupa daftar BarisStruk, bukan teks polos, supaya digambar
  // oleh widget yang SAMA dengan pratinjau nota. Dua penggambar berbeda
  // untuk satu template adalah sumber ketidakcocokan sebelumnya: yang di
  // sini meratakan dengan spasi dan mengabaikan ukuran huruf, yang di
  // sana memakai TextAlign dan membesarkan huruf sesuai skala.
  List<BarisStruk>? get _barisPratinjau {
    final cfg = StrukConfig.dari(Settings.instance).salin(
      template: _utama.text,
      templateItem: _item.text,
    );
    try {
      return Struk.render(notaContoh(), cfg);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Template Struk'),
          actions: [
            IconButton(
                onPressed: _bantuan,
                icon: const Icon(Icons.help_outline),
                tooltip: 'Cara pakai'),
            IconButton(
                onPressed: _laci,
                icon: const Icon(Icons.folder_open_outlined),
                tooltip: 'Template tersimpan'),
            IconButton(
                onPressed: _reset,
                icon: const Icon(Icons.restart_alt),
                tooltip: 'Kembalikan bawaan'),
            IconButton(
                onPressed: _simpan,
                icon: const Icon(Icons.save_outlined),
                tooltip: 'Simpan'),
          ],
          bottom: const TabBar(tabs: [
            Tab(text: 'Struk'),
            Tab(text: 'Baris Item'),
            Tab(text: 'Pratinjau'),
          ]),
        ),
        body: TabBarView(
          children: [
            _tabEditor(
              ctrl: _utama,
              fokus: _fokusUtama,
              indeks: 0,
              placeholder: _placeholderUtama,
              info:
                  'Kerangka struk. Ketik teks tetap apa adanya, sisipkan placeholder untuk bagian yang berubah.',
            ),
            _tabEditor(
              ctrl: _item,
              fokus: _fokusItem,
              indeks: 1,
              placeholder: Struk.placeholderItem,
              info:
                  'Bentuk SATU baris item. Pola ini diulang otomatis untuk setiap layanan di nota.',
            ),
            _tabPratinjau(),
          ],
        ),
      ),
    );
  }

  Widget _tabEditor({
    required TextEditingController ctrl,
    required FocusNode fokus,
    required int indeks,
    required Map<String, String> placeholder,
    required String info,
  }) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Colors.black.withAlpha(12),
          padding: const EdgeInsets.all(12),
          child: Text(info, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: ctrl,
              focusNode: fokus,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: const InputDecoration(
                alignLabelWithHint: true,
                hintText: 'Ketik isi struk di sini',
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        SizedBox(
          height: 132,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 4),
                  child: Text('Ketuk untuk menyisipkan:',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    ...placeholder.entries.map(
                      (e) => ActionChip(
                        label: Text(e.key,
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 11)),
                        tooltip: e.value,
                        onPressed: () {
                          setState(() => _aktif = indeks);
                          _sisip(e.key);
                        },
                      ),
                    ),
                    ...['[C]', '[R]', '[B]', '[H]', '[>]', '---'].map(
                      (t) => ActionChip(
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        label: Text(t,
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 11)),
                        onPressed: () {
                          setState(() => _aktif = indeks);
                          _sisip(t);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tabPratinjau() {
    final s = Settings.instance;
    final baris = _barisPratinjau;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Contoh hasil pada kertas ${s.lebarKertas} karakter '
          '(${s.keteranganKertas}). Tampilan ini sama persis dengan '
          'pratinjau sebelum mencetak.',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        if (baris == null)
          KertasPutih(
            child: Text(
              'Template belum bisa ditampilkan.\n'
              'Biasanya ada tag yang belum ditutup, misalnya [C tanpa ].',
              style: TextStyle(fontSize: 12, color: Colors.red.shade700),
            ),
          )
        else
          KertasStruk(baris: baris, lebar: s.lebarKertas),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _utama.text));
            pesan(context, 'Template disalin ke clipboard.');
          },
          icon: const Icon(Icons.copy_all_outlined),
          label: const Text('Salin template'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _simpan,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Simpan Template'),
        ),
      ],
    );
  }
}
