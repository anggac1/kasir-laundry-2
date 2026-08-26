// Potongan UI yang dipakai berulang di banyak layar.

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
