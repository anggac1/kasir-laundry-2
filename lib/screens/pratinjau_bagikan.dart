import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../export/bagikan_nota.dart';
import '../models/models.dart';
import '../store/settings.dart';
import '../ui/umum.dart';
import 'pratinjau.dart';

// Pratinjau apa yang akan diterima pelanggan, sebelum benar-benar dikirim.
//
// Ada karena tidak semua bisa dicek dari emulator: emulator tidak punya
// WhatsApp, jadi tanpa layar ini hasil bagikan hanya bisa ditebak.
class PratinjauBagikanScreen extends StatefulWidget {
  final Nota nota;

  const PratinjauBagikanScreen({required this.nota, super.key});

  @override
  State<PratinjauBagikanScreen> createState() => _PratinjauBagikanState();
}

class _PratinjauBagikanState extends State<PratinjauBagikanScreen> {
  String? _gambarPath;
  String? _pdfPath;
  bool _memuat = true;
  String? _galat;

  @override
  void initState() {
    super.initState();
    _siapkan();
  }

  // #Membuat berkas yang sama persis dengan yang nanti dibagikan
  Future<void> _siapkan() async {
    try {
      final teks = BagikanNota.teksStruk(widget.nota);
      final gambar = await BagikanNota.instance.buatGambar(widget.nota);
      final pdf = await BagikanNota.instance.buatPdf(widget.nota, teks);
      if (!mounted) return;
      setState(() {
        _gambarPath = gambar;
        _pdfPath = pdf;
        _memuat = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _galat = '$e';
        _memuat = false;
      });
    }
  }

  Future<void> _bagikan() async {
    final format = await pilihFormatBagikan(context);
    if (format == null || format.isEmpty || !mounted) return;
    final ok = await BagikanNota.instance.bagikan(context, widget.nota, format);
    if (!mounted) return;
    if (!ok) pesan(context, 'Gagal menyiapkan berkas.', galat: true);
  }

  @override
  Widget build(BuildContext context) {
    final teks = BagikanNota.teksStruk(widget.nota);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pratinjau Bagikan'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.text_fields), text: 'Teks'),
              Tab(icon: Icon(Icons.image_outlined), text: 'Gambar'),
              Tab(icon: Icon(Icons.picture_as_pdf_outlined), text: 'PDF'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _tabTeks(teks),
            _tabGambar(),
            _tabPdf(),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton.icon(
              onPressed: _bagikan,
              icon: const Icon(Icons.share_outlined),
              label: const Text('Bagikan Sekarang'),
            ),
          ),
        ),
      ),
    );
  }

  // Teks ditampilkan dengan huruf monospace berlatar putih, sama seperti
  // yang akan tampil di chat pelanggan.
  Widget _tabTeks(String teks) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _Keterangan(
            'Inilah yang tertempel di chat. Ukuran huruf memang hilang, '
            'karena WhatsApp tidak mengenalnya; perataan dan lebar kolom '
            'tetap dipertahankan.',
          ),
          const SizedBox(height: 12),
          KertasPutih(
            child: SelectableText(
              teks,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.35,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: teks));
              pesan(context, 'Teks nota disalin.');
            },
            icon: const Icon(Icons.copy),
            label: const Text('Salin teks'),
          ),
        ],
      );

  Widget _tabGambar() {
    if (_memuat) return const _Menunggu('Menyiapkan gambar...');
    if (_galat != null) return _Gagal(_galat!);
    final path = _gambarPath;
    if (path == null) {
      return const _Gagal('Gambar gagal dibuat di perangkat ini.');
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _Keterangan(
          'Paling mirip struk aslinya. Ukuran huruf ikut terlihat, jadi '
          'baris besar tetap besar.',
        ),
        const SizedBox(height: 12),
        // width: infinity supaya gambarnya melebar penuh mengikuti layar.
        // Tanpa itu, Image.file menggambar sebesar piksel aslinya, dan
        // struk 32 kolom tampil sebagai gambar kecil di pojok kiri.
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Image.file(
            File(path),
            width: double.infinity,
            fit: BoxFit.fitWidth,
            // Berkasnya ditimpa tiap kali dibuat ulang, sedangkan Flutter
            // menyimpan gambar berdasarkan alamat berkasnya. Tanpa ini,
            // yang tampil bisa gambar lama dari nota sebelumnya.
            key: ValueKey('$path-${File(path).lengthSync()}'),
          ),
        ),
        const SizedBox(height: 12),
        Text('Berkas: ${path.split('/').last}',
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _tabPdf() {
    if (_memuat) return const _Menunggu('Menyiapkan PDF...');
    if (_galat != null) return _Gagal(_galat!);
    final path = _pdfPath;
    final ukuran = path == null ? 0 : File(path).lengthSync();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _Keterangan(
          'PDF memakai huruf monospace dengan lebar halaman mengikuti '
          'kertas struk, jadi kolomnya lurus dan bisa dicetak ulang.',
        ),
        const SizedBox(height: 12),
        // Isi PDF tidak dibaca ulang dari berkasnya: menampilkannya butuh
        // pustaka pembaca PDF yang membengkakkan ukuran aplikasi. Yang
        // digambar di sini adalah baris yang SAMA dengan yang dipakai
        // menyusun PDF-nya, lewat widget yang sama pula, jadi bentuknya
        // memang sama walau bukan berkas PDF-nya sendiri.
        KertasStrukPutih(
          baris: BagikanNota.barisStruk(widget.nota),
          lebar: Settings.instance.lebarKertas,
        ),
        const SizedBox(height: 12),
        Text(
          path == null
              ? 'PDF gagal dibuat.'
              : 'Berkas: ${path.split('/').last}  -  '
                  '${(ukuran / 1024).toStringAsFixed(1)} KB',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}

class _Keterangan extends StatelessWidget {
  final String teks;
  const _Keterangan(this.teks);

  @override
  Widget build(BuildContext context) => Text(teks,
      style: const TextStyle(fontSize: 12, color: Colors.grey));
}

class _Menunggu extends StatelessWidget {
  final String teks;
  const _Menunggu(this.teks);

  @override
  Widget build(BuildContext context) => Center(
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

class _Gagal extends StatelessWidget {
  final String pesanGalat;
  const _Gagal(this.pesanGalat);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: SelectableText(pesanGalat,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade700)),
        ),
      );
}
