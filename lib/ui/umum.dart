// Potongan UI yang dipakai berulang di banyak layar.

import 'dart:async';

import 'package:flutter/material.dart';

// Snackbar seragam. Sebelumnya disalin di 4 layar.
void pesan(BuildContext context, String teks, {bool galat = false}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(teks),
        backgroundColor: galat ? Colors.red.shade700 : null,
        duration: Duration(seconds: galat ? 5 : 2),
      ),
    );
}

// Dialog hapus merah. Mengembalikan true bila pengguna menekan Hapus.
Future<bool> konfirmasiHapus(
  BuildContext context, {
  required String judul,
  required String isi,
  String tombol = 'Hapus',
}) async {
  final ya = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(judul),
      content: Text(isi),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, true),
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          child: Text(tombol),
        ),
      ],
    ),
  );
  return ya ?? false;
}

// Dialog satu kolom isian. Mengembalikan null bila dibatalkan.
Future<String?> dialogIsian(
  BuildContext context, {
  required String judul,
  String awal = '',
  String? label,
  String? bantuan,
  TextInputType? tipe,
  int maxBaris = 1,
}) async {
  final ctrl = TextEditingController(text: awal);
  try {
    return await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(judul),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: tipe,
          maxLines: maxBaris,
          decoration: InputDecoration(labelText: label, helperText: bantuan),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, ctrl.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  } finally {
    ctrl.dispose();
  }
}

// Judul seksi abu-abu kecil di atas sekelompok isian.
class JudulSeksi extends StatelessWidget {
  final String teks;
  final String? catatan;

  const JudulSeksi(this.teks, {this.catatan, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            teks.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: Colors.grey.shade600,
            ),
          ),
          if (catatan != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                catatan!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
        ],
      ),
    );
  }
}

// Baris "label ..... nilai" untuk kartu ringkasan.
class BarisNilai extends StatelessWidget {
  final String label;
  final String nilai;
  final bool tebal;

  const BarisNilai(this.label, this.nilai, {this.tebal = false, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            nilai,
            style: TextStyle(
              fontSize: 13,
              fontWeight: tebal ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// Kotak teks monospace gelap untuk menampilkan kode atau data mentah.
class KotakKode extends StatelessWidget {
  final String teks;
  final double tinggiMaks;

  const KotakKode(this.teks, {this.tinggiMaks = 400, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: tinggiMaks),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          teks,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            height: 1.45,
            color: Color(0xFFD4D4D4),
          ),
        ),
      ),
    );
  }
}

// Bidang putih menyerupai kertas struk, untuk pratinjau.
class KertasPutih extends StatelessWidget {
  final Widget child;

  const KertasPutih({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(6),
      ),
      child: child,
    );
  }
}

// Kolom nama pelanggan dengan saran dari nota yang sudah pernah dibuat.
//
// Saran dicari setelah jeda singkat, bukan tiap ketukan tombol, supaya
// mengetik cepat tidak menembak database berkali-kali.
class KolomNama extends StatefulWidget {
  final TextEditingController controller;
  final Future<List<String>> Function(String awalan) cariSaran;
  final String label;
  final bool wajib;

  // Dipanggil saat pengguna menekan silang di sebelah satu saran. Nama itu
  // tidak akan muncul lagi. Kalau null, tombol silangnya tidak ditampilkan.
  final Future<void> Function(String nama)? hapusSaran;

  const KolomNama({
    required this.controller,
    required this.cariSaran,
    this.hapusSaran,
    this.label = 'Nama pelanggan',
    this.wajib = true,
    super.key,
  });

  @override
  State<KolomNama> createState() => _KolomNamaState();
}

class _KolomNamaState extends State<KolomNama> {
  final _fokus = FocusNode();
  Timer? _jeda;
  List<String> _saran = [];
  bool _tampil = false;

  @override
  void initState() {
    super.initState();
    _fokus.addListener(() {
      if (!_fokus.hasFocus) setState(() => _tampil = false);
    });
  }

  @override
  void dispose() {
    _jeda?.cancel();
    _fokus.dispose();
    super.dispose();
  }

  void _ketik(String v) {
    _jeda?.cancel();
    _jeda = Timer(const Duration(milliseconds: 250), () async {
      final hasil = await widget.cariSaran(v);
      if (!mounted) return;
      setState(() {
        // Nama yang sudah diketik lengkap tidak perlu disarankan lagi.
        _saran = hasil
            .where((n) => n.toLowerCase() != v.trim().toLowerCase())
            .toList();
        _tampil = _saran.isNotEmpty && _fokus.hasFocus;
      });
    });
  }

  Future<void> _hapus(String nama) async {
    await widget.hapusSaran?.call(nama);
    if (!mounted) return;
    setState(() {
      _saran = _saran.where((n) => n != nama).toList();
      _tampil = _saran.isNotEmpty;
    });
  }

  void _pilih(String nama) {
    widget.controller
      ..text = nama
      ..selection = TextSelection.collapsed(offset: nama.length);
    setState(() => _tampil = false);
    _fokus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _fokus,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            label: widget.wajib ? labelWajib(widget.label) : Text(widget.label),
            prefixIcon: const Icon(Icons.person_outline),
            suffixIcon: widget.controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Hapus',
                    onPressed: () {
                      widget.controller.clear();
                      setState(() => _tampil = false);
                    },
                  ),
          ),
          onChanged: (v) {
            setState(() {});
            _ketik(v);
          },
        ),
        if (_tampil)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                for (final n in _saran)
                  InkWell(
                    onTap: () => _pilih(n),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Row(
                        children: [
                          Icon(Icons.history,
                              size: 18, color: Colors.grey.shade600),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(n,
                                style: const TextStyle(fontSize: 15),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          // Salah ketik nama pelanggan akan terus muncul di
                          // saran kalau tidak bisa dibuang dari sini.
                          if (widget.hapusSaran != null)
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              tooltip: 'Hapus dari saran',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _hapus(n),
                            )
                          else
                            const SizedBox(width: 12),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

// Tombol cepat menambah nol pada kolom angka.
//
// Mengetik 7 lalu menekan +000 jauh lebih cepat daripada mengetik 7000,
// dan lebih kecil kemungkinan salah hitung nolnya. Hanya +0 dan +000
// yang disediakan: +00 jarang dipakai dan hanya menambah tombol.
class TombolNol extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? sesudah;

  const TombolNol({required this.controller, this.sesudah, super.key});

  void _tambah(String nol) {
    final teks = controller.text.trim();
    // Tidak ada gunanya membuat "000" dari kolom kosong.
    if (teks.isEmpty || teks == '0') return;
    final baru = teks + nol;
    controller
      ..text = baru
      ..selection = TextSelection.collapsed(offset: baru.length);
    sesudah?.call();
  }

  @override
  Widget build(BuildContext context) {
    Widget tombol(String nol) => Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: OutlinedButton(
              onPressed: () => _tambah(nol),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                minimumSize: const Size(0, 44),
              ),
              child: Text('+$nol',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          tombol('0'),
          tombol('000'),
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                controller.clear();
                sesudah?.call();
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                minimumSize: const Size(0, 44),
              ),
              child: const Text('C', style: TextStyle(fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

// Tanda bintang merah untuk isian yang wajib, seperti di Google Form.
Widget labelWajib(String teks) => RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 15, color: Colors.black87),
        children: [
          TextSpan(text: teks),
          const TextSpan(
            text: ' *',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );

// Sama, tapi untuk labelText di dalam InputDecoration yang hanya mau String.
// Bintangnya diwarnai lewat InputDecoration.label, bukan labelText.
InputDecoration hiasanWajib({
  required String label,
  String? hint,
  String? bantuan,
  Widget? ikon,
  String? prefix,
  Widget? suffix,
}) =>
    InputDecoration(
      label: labelWajib(label),
      hintText: hint,
      helperText: bantuan,
      prefixIcon: ikon,
      prefixText: prefix,
      suffixIcon: suffix,
    );
