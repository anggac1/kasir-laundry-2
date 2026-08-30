import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/db.dart';
import '../export/bagikan_nota.dart';
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

  // Bentuk yang sedang dilihat di tab Pratinjau:
  // 0 struk di layar, 1 teks polos, 2 gambar, 3 PDF.
  int _bentuk = 0;

  String? _gambarPath;
  String? _pdfPath;
  // Ukuran piksel gambar yang sudah jadi, dibaca dari berkasnya sendiri
  // supaya angkanya hasil ukur, bukan menyalin nilai setelan.
  Size? _ukuranGambar;
  bool _menyiapkan = false;
  // Menandai berkas hasil template yang SUDAH berubah, supaya gambar
  // dan PDF-nya dibuat ulang, bukan menampilkan yang basi.
  String _sidikTerakhir = '';

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
      if (!mounted) return;
      setState(() {});
      // Kalau yang sedang dilihat gambar atau PDF, berkasnya ikut
      // dibuat ulang. Tanpa ini, mengetik sambil membuka tab Gambar
      // membuat yang tampil tetap gambar template yang lama - persis
      // jenis ketidakcocokan yang mau dihilangkan tab ini.
      if (_bentuk == 2 || _bentuk == 3) _siapkanBerkas();
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
    // Tombolnya merah dan bertanya dulu, sama seperti aksi berbahaya
    // lainnya: sekali ditekan, teks yang disusun sendiri tidak bisa
    // dikembalikan.
    final ya = await konfirmasiHapus(
      context,
      judul: 'Yakin kembalikan template bawaan?',
      isi: 'Kerangka struk dan bentuk baris item yang Anda susun akan '
          'hilang, diganti bawaan. Tidak ada cara mengembalikannya.\n\n'
          'Laci template tidak ikut terhapus.',
      tombol: 'Kembalikan',
    );
    if (!ya) return;
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
            'pada nota. Bentuk tiap barisnya diatur di tab Pengaturan.\n\n'
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
          // Tiga ikon saja. "Kembalikan bawaan" pindah ke tab Pengaturan
          // karena tempatnya memang di sana bersama setelan lain, dan
          // empat ikon berdesakan dengan judul di layar sempit.
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
                onPressed: _simpan,
                icon: const Icon(Icons.save_outlined),
                tooltip: 'Simpan'),
          ],
          bottom: const TabBar(tabs: [
            Tab(text: 'Struk'),
            Tab(text: 'Pratinjau'),
            Tab(text: 'Pengaturan'),
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
            _tabPratinjau(),
            _tabPengaturan(),
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

  // Tab Pengaturan: semua yang mempengaruhi bentuk struk dan berkas
  // yang dikirim ke pelanggan, dikumpulkan di satu tempat.
  //
  // Nama berkas dan Ukuran gambar dulunya ada di layar Pengaturan utama.
  // Dipindah ke sini supaya hasilnya bisa langsung dilihat di tab
  // Pratinjau sebelah, tanpa berpindah layar.
  Widget _tabPengaturan() {
    final s = Settings.instance;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ---- Pola baris item -------------------------------------
        const Text('Bentuk Baris Item',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text(
          'Bentuk SATU baris layanan. Pola ini diulang otomatis untuk '
          'tiap item, lalu menggantikan {daftar_item} di kerangka struk.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _item,
          focusNode: _fokusItem,
          maxLines: 3,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 2,
          children: Struk.placeholderItem.entries
              .map((e) => ActionChip(
                    label: Text(e.key,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 11)),
                    tooltip: e.value,
                    onPressed: () {
                      setState(() => _aktif = 1);
                      _sisip(e.key);
                    },
                  ))
              .toList(),
        ),

        const Divider(height: 32),

        // ---- Nama berkas -----------------------------------------
        const Text('Berkas untuk Pelanggan',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.drive_file_rename_outline),
          title: const Text('Nama berkas'),
          subtitle: Text(s.polaNamaBerkas),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final baru = await dialogIsian(
              context,
              judul: 'Pola nama berkas',
              awal: s.polaNamaBerkas,
              label: 'Pola',
              bantuan: 'Boleh pakai {nama}, {tanggal}, {toko}, {no_nota}',
            );
            if (baru == null) return;
            await s.setPolaNamaBerkas(baru);
            if (mounted) setState(() {});
          },
        ),
        const Text(
          'Nama berkas yang diterima pelanggan. Bawaannya tanpa nomor '
          'nota, karena kode seperti LDY-260830-001 tidak ada gunanya '
          'bagi pelanggan.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),

        // ---- Ukuran gambar ---------------------------------------
        Row(
          children: [
            const Icon(Icons.photo_size_select_large),
            const SizedBox(width: 16),
            const Expanded(child: Text('Ukuran gambar')),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: s.lebarGambar <= 400
                  ? null
                  : () async {
                      await s.setLebarGambar(s.lebarGambar - 200);
                      if (mounted) setState(() {});
                      await _siapkanBerkas();
                    },
            ),
            Text('${s.lebarGambar}',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: s.lebarGambar >= 2000
                  ? null
                  : () async {
                      await s.setLebarGambar(s.lebarGambar + 200);
                      if (mounted) setState(() {});
                      await _siapkanBerkas();
                    },
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Petunjuk yang IKUT BERUBAH saat ukurannya diganti.
        //
        // Angka piksel saja tidak menjelaskan apa-apa, dan gambarnya
        // sendiri memang tidak bisa dipakai membandingkan: ukuran huruf
        // dihitung dari lebar gambar, jadi 600 dan 1600 menghasilkan
        // gambar yang identik bentuknya - yang satu cuma versi
        // perbesaran yang lain. Yang benar-benar berubah cuma
        // kerapatan, besar berkas, dan ketajaman saat di-zoom. Tiga hal
        // itulah yang ditampilkan di sini.
        _petunjukUkuran(s.lebarGambar),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          children: [
            for (final n in const [400, 600, 800, 1200, 1600, 2000])
              ChoiceChip(
                label: Text('$n'),
                selected: s.lebarGambar == n,
                onSelected: (_) async {
                  await s.setLebarGambar(n);
                  if (mounted) setState(() {});
                  // Berkasnya dibuat ulang sekarang juga, supaya begitu
                  // pindah ke tab Pratinjau yang tampil sudah ukuran
                  // yang baru, bukan gambar lama.
                  await _siapkanBerkas();
                },
              ),
          ],
        ),

        const SizedBox(height: 4),
        // ---- Kata pengantar --------------------------------------
        //
        // Kalimat sapaan yang menemani lampiran, BUKAN isi struknya.
        // Struknya sudah ada di gambar/PDF yang dilampirkan.
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.chat_bubble_outline),
          title: const Text('Kata pengantar'),
          subtitle: Text('"${BagikanNota.pesanPengantar(notaContoh())}"'),
          trailing: const Icon(Icons.chevron_right),
          isThreeLine: true,
          onTap: () async {
            final baru = await dialogIsian(
              context,
              judul: 'Kata pengantar',
              awal: s.pesanPengantar,
              label: 'Pesan',
              maxBaris: 3,
              bantuan: 'Boleh pakai {nama}, {toko}, {tanggal}, {no_nota}, '
                  '{total}',
            );
            if (baru == null) return;
            await s.setPesanPengantar(baru);
            if (mounted) setState(() {});
          },
        ),
        const Text(
          'Kalimat yang menemani lampiran di chat pelanggan, seperti '
          'mengirim pesan biasa. Isi struknya sendiri sudah ada di dalam '
          'gambar atau PDF, jadi tidak perlu diketik lagi di sini.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        // Contoh nyata, memakai fungsi yang SAMA dengan saat mengirim,
        // supaya yang terlihat di sini benar-benar yang diterima.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFDCF8C6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.insert_drive_file_outlined,
                      size: 18, color: Colors.grey.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      BagikanNota.namaBerkas(notaContoh(), 'pdf'),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(BagikanNota.pesanPengantar(notaContoh()),
                  style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Contoh tampilan di chat pelanggan.',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),

        const Divider(height: 32),

        // ---- Aksi berbahaya --------------------------------------
        Text('Berbahaya',
            style: TextStyle(
                fontWeight: FontWeight.w700, color: Colors.red.shade700)),
        const SizedBox(height: 4),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.restart_alt, color: Colors.red.shade700),
          title: Text('Kembalikan template bawaan',
              style: TextStyle(color: Colors.red.shade700)),
          subtitle: const Text(
              'Kerangka struk dan bentuk baris item kembali seperti baru. '
              'Laci template tidak ikut terhapus.'),
          isThreeLine: true,
          onTap: _reset,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // #Petunjuk yang berubah nyata mengikuti setelan ukuran gambar
  //
  // Dibuat karena membandingkan gambarnya sendiri memang percuma:
  // ukuran hurufnya dihitung dari lebar gambar, sehingga semua ukuran
  // menghasilkan gambar yang sebangun - 1600 hanyalah 600 yang
  // diperbesar. Di layar keduanya dipaskan ke lebar yang sama, jadi
  // identik. Yang berbeda ada tiga, dan ketiganya ditampilkan di sini
  // sebagai angka dan batang, bukan sebagai kalimat penjelasan.
  Widget _petunjukUkuran(int lebar) {
    // Batang perbandingan: sepanjang lebar relatif terhadap yang
    // terbesar, jadi bedanya terlihat sebagai panjang, bukan angka.
    const maks = 2000.0;
    final rasio = lebar / maks;

    // Ketajaman = berapa kali lipat piksel dibanding lebar layar HP
    // pada umumnya. Di bawah 1x berarti tulisannya melar saat dibuka.
    const layarKhas = 360.0;
    final rapat = lebar / layarKhas;

    final (label, warna) = rapat < 1.4
        ? ('Kurang tajam kalau di-zoom', Colors.orange.shade800)
        : rapat < 2.5
            ? ('Cukup untuk dibaca langsung', Colors.green.shade700)
            : ('Tajam sampai di-zoom jauh', Colors.green.shade700);

    // Perkiraan besar berkas hanya dipakai kalau berkasnya BELUM ada.
    // Begitu gambarnya benar-benar dibuat, angkanya diganti hasil ukur.
    final path = _gambarPath;
    String besar;
    if (path != null && _ukuranGambar?.width.round() == lebar) {
      final kb = File(path).lengthSync() / 1024;
      besar = kb >= 1024
          ? '${(kb / 1024).toStringAsFixed(1)} MB'
          : '${kb.toStringAsFixed(0)} KB';
    } else {
      besar = 'dihitung saat dibuat';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Batang panjangnya ikut ukuran - ini yang paling cepat
          // terlihat waktu tombolnya ditekan.
          LayoutBuilder(
            builder: (ctx, batas) => Stack(
              children: [
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                Container(
                  height: 10,
                  width: batas.maxWidth * rasio,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.primary,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _barisPetunjuk('Lebar gambar', '$lebar piksel'),
          _barisPetunjuk('Dibanding layar HP', '${rapat.toStringAsFixed(1)}x'),
          _barisPetunjuk('Besar berkas', besar),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(rapat < 1.4 ? Icons.warning_amber : Icons.check_circle,
                  size: 15, color: warna),
              const SizedBox(width: 5),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: warna)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _barisPetunjuk(String kiri, String kanan) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(kiri,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(kanan,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  // #Melihat gambar pada ukuran piksel penuh, bisa digeser dan di-zoom
  //
  // Ada karena semua pilihan ukuran lebih lebar daripada layar HP:
  // tanpa bisa diperbesar, 600 dan 1600 sama-sama memenuhi lebar layar
  // dan setelan ukurannya terasa tidak berpengaruh apa pun.
  void _lihatPenuh(String path) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _ukuranGambar == null
                          ? 'Gambar nota'
                          : '${_ukuranGambar!.width.toInt()} x '
                              '${_ukuranGambar!.height.toInt()} piksel',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            // Digambar pada ukuran piksel ASLINYA, di dalam kotak yang
            // bisa digeser dua arah.
            //
            // Inilah satu-satunya tempat perbedaan ukuran benar-benar
            // terlihat sebagai besar-kecil: gambar 1600 px memenuhi
            // layar dan harus digeser, sedangkan 600 px muat begitu
            // saja. Kalau di sini pun dipaskan ke lebar layar, semua
            // ukuran akan tampak sama seperti sebelumnya.
            Flexible(
              child: InteractiveViewer(
                maxScale: 8,
                minScale: 0.1,
                constrained: false,
                child: Image.file(File(path),
                    key: ValueKey('penuh-$path-$_sidikTerakhir')),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Ukuran asli 1:1, geser untuk melihat bagian lain. '
                'Cubit untuk memperbesar atau mengecilkan.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // #Menggambar isi pratinjau sesuai bentuk yang dipilih
  Widget _isiPratinjau(List<BarisStruk> baris, Settings s) {
    switch (_bentuk) {
      case 1:
        // Teks polos memakai fungsi yang SAMA dengan yang dipakai saat
        // benar-benar mengirim, jadi tidak mungkin berbeda.
        return KertasPutih(
          child: SelectableText(
            Struk.pratinjau(baris, s.lebarKertas, rapikan: true),
            textScaler: TextScaler.noScaling,
            style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                height: 1.35,
                color: Colors.black),
          ),
        );
      case 2:
        if (_menyiapkan) return const _Menyiapkan('Menyiapkan gambar...');
        final p = _gambarPath;
        if (p == null) {
          return const _GagalKotak('Gambar gagal dibuat di perangkat ini.');
        }
        // Gambar TIDAK dipaksa selebar layar.
        //
        // Sebelumnya dipakai width: double.infinity + BoxFit.fitWidth,
        // yang meregangkan gambar 600 piksel dan 1600 piksel ke lebar
        // yang sama persis - jadi mengubah setelan ukuran tidak
        // kelihatan sama sekali. Sekarang digambar sebesar piksel
        // aslinya, dan baru dikecilkan kalau memang lebih lebar dari
        // layar, sehingga bedanya benar-benar terlihat.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => _lihatPenuh(p),
              child: Container(
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300)),
                child: Image.file(
                  File(p),
                  fit: BoxFit.scaleDown,
                  // Berkasnya ditimpa tiap kali dibuat ulang, sedangkan
                  // Flutter menyimpan gambar berdasarkan alamat
                  // berkasnya. Tanpa kunci yang ikut berubah, yang
                  // tampil bisa gambar lama.
                  key: ValueKey('$p-$_sidikTerakhir'),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.zoom_in, size: 15, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Ketuk untuk melihat ukuran asli 1:1 - di sana gambar '
                    'yang lebih besar benar-benar lebih besar, tidak '
                    'dipaskan ke lebar layar.',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Ukuran sungguhannya ditulis, karena di layar sempit gambar
            // besar tetap harus dikecilkan supaya muat - tanpa angka ini
            // 1200 dan 1600 bisa terlihat sama.
            Text(
              _ukuranGambar == null
                  ? 'Berkas: ${p.split('/').last}'
                  : '${_ukuranGambar!.width.toInt()} x '
                      '${_ukuranGambar!.height.toInt()} piksel  -  '
                      '${(File(p).lengthSync() / 1024).toStringAsFixed(0)} KB',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        );
      case 3:
        if (_menyiapkan) return const _Menyiapkan('Menyiapkan PDF...');
        // Isi PDF tidak dibaca ulang dari berkasnya: menampilkannya butuh
        // pustaka pembaca PDF yang membengkakkan ukuran aplikasi. Yang
        // digambar di sini baris yang SAMA dengan penyusun PDF-nya.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KertasStrukPutih(baris: baris, lebar: s.lebarKertas),
            const SizedBox(height: 8),
            Text(
              _pdfPath == null
                  ? 'PDF gagal dibuat.'
                  : 'Berkas: ${_pdfPath!.split('/').last}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        );
      default:
        return KertasStrukPutih(baris: baris, lebar: s.lebarKertas);
    }
  }

  // #Membuat gambar dan PDF dari template yang SEDANG diketik
  //
  // Dibuat ulang hanya kalau templatenya benar-benar berubah, karena
  // menggambar PNG dan menyusun PDF jauh lebih mahal daripada menggambar
  // struk di layar.
  Future<void> _siapkanBerkas() async {
    final baris = _barisPratinjau;
    if (baris == null) return;
    final sidik = '${_utama.text}|${_item.text}|'
        '${Settings.instance.lebarGambar}|${Settings.instance.lebarKertas}';
    if (sidik == _sidikTerakhir && (_gambarPath != null || _pdfPath != null)) {
      return;
    }

    setState(() => _menyiapkan = true);
    try {
      final nota = notaContoh();
      final teks = Struk.pratinjau(baris, Settings.instance.lebarKertas,
          rapikan: true);
      final g = await BagikanNota.instance.buatGambar(nota, barisLuar: baris);
      final f =
          await BagikanNota.instance.buatPdf(nota, teks, barisLuar: baris);

      // Ukuran dibaca dari berkas hasilnya, bukan dari nilai setelan.
      // Kalau pembuatan gambarnya meleset, angkanya ikut memperlihatkan
      // kelesetan itu, bukan menutupinya.
      Size? ukuran;
      if (g != null) {
        try {
          final byte = await File(g).readAsBytes();
          // instantiateImageCodec dipanggil lewat dart:ui secara langsung,
          // bukan lewat pembungkus di material, supaya tidak bergantung
          // pada apa yang kebetulan ikut diekspor ulang.
          final codec = await ui.instantiateImageCodec(byte);
          final bingkai = await codec.getNextFrame();
          ukuran = Size(bingkai.image.width.toDouble(),
              bingkai.image.height.toDouble());
          bingkai.image.dispose();
          codec.dispose();
        } catch (_) {
          ukuran = null;
        }
      }

      if (!mounted) return;
      setState(() {
        _gambarPath = g;
        _pdfPath = f;
        _ukuranGambar = ukuran;
        _sidikTerakhir = sidik;
        _menyiapkan = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _menyiapkan = false);
    }
  }

  Widget _tabPratinjau() {
    final s = Settings.instance;
    final baris = _barisPratinjau;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Pemilih bentuk: Struk / Teks / Gambar / PDF.
        //
        // Ada di sini supaya semua bentuk yang diterima pelanggan bisa
        // diperiksa sambil menyunting template, tanpa harus membuat nota
        // sungguhan dulu lalu masuk ke layar Bagikan.
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Struk')),
            ButtonSegment(value: 1, label: Text('Teks')),
            ButtonSegment(value: 2, label: Text('Gambar')),
            ButtonSegment(value: 3, label: Text('PDF')),
          ],
          selected: {_bentuk},
          showSelectedIcon: false,
          onSelectionChanged: (v) {
            setState(() => _bentuk = v.first);
            if (_bentuk == 2 || _bentuk == 3) _siapkanBerkas();
          },
        ),
        const SizedBox(height: 12),
        Text(
          _bentuk == 1
              ? 'Bentuk teks polos, seperti yang tertempel di chat. '
                  'Ukuran huruf hilang karena WhatsApp tidak mengenalnya; '
                  'perataan dan lebar kolom tetap.'
              : _bentuk == 2
                  ? 'Gambar yang dikirim ke pelanggan, lebar '
                      '${s.lebarGambar} piksel. Ukuran huruf ikut terlihat.'
                  : _bentuk == 3
                      ? 'PDF dengan lebar halaman mengikuti kertas struk, '
                          'jadi kolomnya lurus dan bisa dicetak ulang.'
                      : 'Contoh hasil pada kertas ${s.lebarKertas} karakter '
                          '(${s.keteranganKertas}). Tampilan ini sama persis '
                          'dengan pratinjau sebelum mencetak.',
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
          _isiPratinjau(baris, s),
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

// Penanda sedang menyiapkan berkas, setinggi kertas supaya tata letaknya
// tidak melompat waktu gambar selesai dibuat.
class _Menyiapkan extends StatelessWidget {
  final String teks;
  const _Menyiapkan(this.teks);

  @override
  Widget build(BuildContext context) => Container(
        height: 180,
        alignment: Alignment.center,
        decoration:
            BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(teks, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
}

class _GagalKotak extends StatelessWidget {
  final String teks;
  const _GagalKotak(this.teks);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        decoration:
            BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
        child: Text(teks,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red.shade700)),
      );
}
