import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../db/db.dart';
import '../store/settings.dart';
import '../ui/umum.dart';

// Dialog "Hapus data" dengan pilihan centang.
//
// Android bawaannya cuma menyediakan satu tombol "hapus cache" yang
// membabi buta. Di sini pengguna memilih sendiri apa yang dibuang, jadi
// membersihkan berkas menumpuk tidak harus ikut mengorbankan nota.
//
// Urutannya sengaja dari yang paling aman ke yang paling berbahaya, dan
// dua yang terakhir ditandai merah.

enum _Pilihan { berkas, saranNama, semuaNota, setelan }

class _Baris {
  final _Pilihan id;
  final String judul;
  final String keterangan;
  final bool bahaya;
  const _Baris(this.id, this.judul, this.keterangan, {this.bahaya = false});
}

const _daftar = [
  _Baris(
    _Pilihan.berkas,
    'Berkas sementara',
    'PDF dan gambar nota yang pernah dibagikan atau diekspor. Aman '
        'dihapus: berkasnya dibuat ulang setiap kali dibutuhkan.',
  ),
  _Baris(
    _Pilihan.saranNama,
    'Saran nama pelanggan',
    'Daftar nama yang muncul saat mengetik. Nota tidak ikut terhapus.',
  ),
  _Baris(
    _Pilihan.semuaNota,
    'Semua nota',
    'Seluruh riwayat transaksi hilang permanen, termasuk hutang yang '
        'belum lunas.',
    bahaya: true,
  ),
  _Baris(
    _Pilihan.setelan,
    'Setelan kembali ke bawaan',
    'Nama laundry, alamat, lebar kertas, dan template struk kembali '
        'seperti baru. Laci template TIDAK ikut terhapus.',
    bahaya: true,
  ),
];

// #Menghitung besar berkas sementara, supaya angkanya nyata bukan tebakan
Future<int> _besarBerkas() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    var total = 0;
    for (final f in dir.listSync()) {
      if (f is! File) continue;
      final n = f.path.toLowerCase();
      if (n.endsWith('.pdf') || n.endsWith('.png') || n.endsWith('.xlsx')) {
        total += f.lengthSync();
      }
    }
    return total;
  } catch (_) {
    return 0;
  }
}

// #Menghapus berkas sementara, mengembalikan jumlah yang terhapus
Future<int> _hapusBerkas() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    var n = 0;
    for (final f in dir.listSync()) {
      if (f is! File) continue;
      final nama = f.path.toLowerCase();
      if (nama.endsWith('.pdf') ||
          nama.endsWith('.png') ||
          nama.endsWith('.xlsx')) {
        try {
          f.deleteSync();
          n++;
        } catch (_) {
          // Satu berkas yang sedang dipakai tidak boleh menggagalkan
          // sisanya.
        }
      }
    }
    return n;
  } catch (_) {
    return 0;
  }
}

Future<void> tampilkanHapusData(BuildContext context) async {
  final pilih = <_Pilihan>{};
  var besar = 0;

  besar = await _besarBerkas();
  if (!context.mounted) return;

  final jalan = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLokal) {
        final adaBahaya =
            _daftar.any((b) => b.bahaya && pilih.contains(b.id));
        return AlertDialog(
          title: const Text('Hapus data'),
          contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
                    child: Text(
                      'Centang yang ingin dihapus. Yang tidak dicentang '
                      'tidak tersentuh.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                  ..._daftar.map((b) {
                    final merah = Colors.red.shade700;
                    return CheckboxListTile(
                      value: pilih.contains(b.id),
                      onChanged: (v) => setLokal(() {
                        if (v == true) {
                          pilih.add(b.id);
                        } else {
                          pilih.remove(b.id);
                        }
                      }),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        b.id == _Pilihan.berkas && besar > 0
                            ? '${b.judul}  (${(besar / 1024 / 1024).toStringAsFixed(1)} MB)'
                            : b.judul,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: b.bahaya ? merah : null,
                        ),
                      ),
                      subtitle: Text(b.keterangan,
                          style: const TextStyle(fontSize: 12)),
                      isThreeLine: true,
                    );
                  }),
                  if (adaBahaya)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
                      child: Text(
                        'Pilihan merah tidak bisa dibatalkan.',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade700),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              // Mati selama belum ada yang dicentang, supaya tidak ada
              // tombol Hapus yang tidak mengerjakan apa pun.
              onPressed:
                  pilih.isEmpty ? null : () => Navigator.pop(ctx, true),
              style: adaBahaya
                  ? FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade700)
                  : null,
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    ),
  );

  if (jalan != true || pilih.isEmpty) return;
  if (!context.mounted) return;

  // Konfirmasi kedua HANYA untuk yang tidak bisa dikembalikan.
  final bahaya = _daftar.where((b) => b.bahaya && pilih.contains(b.id));
  if (bahaya.isNotEmpty) {
    final ya = await konfirmasiHapus(
      context,
      judul: 'Yakin hapus?',
      isi: 'Yang akan dihapus permanen:\n\n'
          '${bahaya.map((b) => '- ${b.judul}').join('\n')}\n\n'
          'Tidak ada cara mengembalikannya.',
    );
    if (!ya) return;
    if (!context.mounted) return;
  }

  final hasil = <String>[];
  if (pilih.contains(_Pilihan.berkas)) {
    final n = await _hapusBerkas();
    hasil.add('$n berkas sementara');
  }
  if (pilih.contains(_Pilihan.saranNama)) {
    await Settings.instance.tampilkanSemuaNama();
    hasil.add('saran nama');
  }
  if (pilih.contains(_Pilihan.semuaNota)) {
    await DB.instance.kosongkanTransaksi();
    hasil.add('semua nota');
  }
  if (pilih.contains(_Pilihan.setelan)) {
    await Settings.instance.resetSemuaSetelan();
    hasil.add('setelan');
  }

  if (!context.mounted) return;
  pesan(context, 'Terhapus: ${hasil.join(', ')}.');
}
