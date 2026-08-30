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

class _PratinjauBagikanState extends State<PratinjauBagikanScreen>
    with SingleTickerProviderStateMixin {
  String? _gambarPath;
  String? _pdfPath;
  bool _memuat = true;
  String? _galat;

  late final TabController _tabCtrl;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this)
      ..addListener(() {
        // index berubah dua kali per geseran: saat animasi mulai dan
        // saat selesai. Cukup diperbarui kalau memang berbeda.
        if (_tabCtrl.index != _tab && mounted) {
          setState(() => _tab = _tabCtrl.index);
        }
      });
    _siapkan();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
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

  // #Membagikan format yang sedang dilihat, tanpa bertanya lagi
  //
  // Tidak ada dialog pilihan format: tabnya sudah menyatakan pilihan.
  // Menanyakannya lagi setelah pengguna membuka tab yang diinginkan
  // hanya menambah satu ketukan tanpa guna.
  Future<void> _bagikan() async {
    const urut = [FormatBagikan.teks, FormatBagikan.gambar, FormatBagikan.pdf];
    final ok = await BagikanNota.instance
        .bagikan(context, widget.nota, urut[_tab]);
    if (!mounted) return;
    if (!ok) pesan(context, 'Gagal menyiapkan berkas.', galat: true);
  }

  static const _namaFormat = ['Teks', 'Gambar', 'PDF'];

  // #Ukuran huruf terbesar yang membuat satu baris penuh muat
  //
  // Ditebak lalu DIVERIFIKASI dengan mengukur ulang, sama seperti di
  // KertasStruk. Rumus perbandingan saja tidak cukup: lebar teks tidak
  // selalu tumbuh lurus mengikuti ukuran huruf, dan selisih kecil per
  // huruf menumpuk sepanjang satu baris sampai terpotong.
  static double _ukuranMuat(double ruang, int kolom) {
    if (!ruang.isFinite || ruang <= 0) return 12;
    const acuan = 20.0;

    double ukur(double fs) {
      final tp = TextPainter(
        text: TextSpan(
          text: '0' * kolom,
          style: TextStyle(fontFamily: 'monospace', fontSize: fs),
        ),
        maxLines: 1,
        textScaler: TextScaler.noScaling,
        textDirection: TextDirection.ltr,
      )..layout();
      return tp.width;
    }

    var ukuran = ruang / ukur(acuan) * acuan;
    for (var i = 0; i < 60; i++) {
      if (ukur(ukuran) <= ruang) break;
      ukuran -= 0.25;
      if (ukuran < 6) return 6;
    }
    return ukuran;
  }

  @override
  Widget build(BuildContext context) {
    final teks = BagikanNota.teksStruk(widget.nota);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pratinjau Bagikan'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(icon: Icon(Icons.text_fields), text: 'Teks'),
            Tab(icon: Icon(Icons.image_outlined), text: 'Gambar'),
            Tab(icon: Icon(Icons.picture_as_pdf_outlined), text: 'PDF'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
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
            // Tombolnya menyebut format yang sedang dilihat, supaya
            // jelas apa yang akan terkirim.
            label: Text('Bagikan ${_namaFormat[_tab]}'),
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
          // Ukurannya menyesuaikan lebar layar, bukan dipatok 12.
          //
          // Teks struk lebarnya tetap sebanyak kolom kertas; ukuran huruf
          // yang dipatok membuatnya melipat pada kertas lebar atau saat
          // setelan Ukuran Font di HP dinaikkan. Skala sistem juga
          // dimatikan, dengan alasan yang sama seperti di KertasStruk.
          KertasPutih(
            child: LayoutBuilder(
              builder: (context, batas) {
                final lebarKolom = Settings.instance.lebarKertas;
                final ukuran = _ukuranMuat(batas.maxWidth, lebarKolom);
                return SelectableText(
                  teks,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: ukuran,
                    height: 1.35,
                    color: Colors.black,
                  ),
                );
              },
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
