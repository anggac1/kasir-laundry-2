import 'package:flutter/material.dart';

import '../models/models.dart';
import '../print/printer_service.dart';
import '../ui/umum.dart';

// Cetak sambil menangani masalah printer di tempat.
//
// Kalau gagal, pengguna tidak dilempar keluar untuk membereskan Bluetooth
// lalu harus mencari notanya lagi. Dialog ini menawarkan tombol ke Setelan
// Bluetooth, dan begitu kembali cukup tekan Coba Cetak Lagi.
//
// Mengembalikan true kalau akhirnya tercetak.
Future<bool> cetakDenganPemulihan(BuildContext context, Nota nota) async {
  var hasil = await PrinterService.instance.cetakNota(nota);
  if (hasil.sukses) {
    if (context.mounted) pesan(context, hasil.pesan);
    return true;
  }

  while (context.mounted) {
    final tindakan = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        icon: Icon(Icons.print_disabled, color: Colors.red.shade700, size: 36),
        title: const Text('Gagal Mencetak'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(hasil.pesan, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 14),
              const Text(
                'Nota sudah tersimpan. Bereskan printernya, lalu cetak lagi '
                'dari sini tanpa perlu mengisi ulang.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              if (hasil.langkah.isNotEmpty) ...[
                const SizedBox(height: 12),
                ExpansionTile(
                  title: const Text('Rincian langkah',
                      style: TextStyle(fontSize: 13)),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      color: Colors.grey.shade100,
                      child: SelectableText(
                        hasil.rincian,
                        style: const TextStyle(
                            fontSize: 11, fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, 'batal'),
            child: const Text('Nanti Saja'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(c, 'setelan'),
            icon: const Icon(Icons.settings_bluetooth, size: 20),
            label: const Text('Setelan Bluetooth'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(c, 'ulang'),
            icon: const Icon(Icons.refresh, size: 20),
            label: const Text('Coba Cetak Lagi'),
          ),
        ],
      ),
    );

    if (tindakan == null || tindakan == 'batal') return false;

    if (tindakan == 'setelan') {
      final ok = await PrinterService.instance.bukaSetelanBluetooth();
      if (!context.mounted) return false;
      if (!ok) {
        pesan(context,
            'Tidak bisa membuka Setelan otomatis. Buka Setelan HP lalu '
            'cari Bluetooth.',
            galat: true);
      }
      // Dialog dibuka lagi supaya sepulang dari Setelan, tombol Coba Cetak
      // Lagi sudah menunggu tanpa perlu mencari notanya lagi.
      continue;
    }

    if (!context.mounted) return false;
    pesan(context, 'Menghubungkan ke printer...');
    hasil = await PrinterService.instance.cetakNota(nota);
    if (hasil.sukses) {
      if (context.mounted) pesan(context, hasil.pesan);
      return true;
    }
  }
  return false;
}
