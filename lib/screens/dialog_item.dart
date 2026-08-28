import 'package:flutter/material.dart';

import '../models/models.dart';
import '../ui/umum.dart';
import '../utils/fmt.dart';

/// Dialog jumlah dan harga untuk satu layanan dari daftar.
/// Mengembalikan null bila dibatalkan.
Future<ItemNota?> dialogQtyLayanan(
  BuildContext context,
  Layanan l, {
  ItemNota? edit,
}) async {
  final qtyCtrl = TextEditingController(
    text: edit != null ? qtyStr(edit.qty) : (l.satuan == Satuan.kg ? '' : '1'),
  );
  final hargaCtrl = TextEditingController(
    text: (edit?.harga ?? l.harga).toString(),
  );

  try {
    return await showDialog<ItemNota>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.nama),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: hiasanWajib(
                label: l.satuan == Satuan.kg ? 'Berat (kg)' : 'Jumlah (pcs)',
                bantuan: l.satuan == Satuan.kg
                    ? 'Boleh desimal, contoh 3.5'
                    : 'Angka bulat',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: hargaCtrl,
              keyboardType: TextInputType.number,
              decoration: hiasanWajib(
                label: 'Harga per ${l.satuan}',
                prefix: 'Rp ',
                bantuan: 'Bisa diubah khusus nota ini',
              ),
            ),
            TombolNol(controller: hargaCtrl),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final q = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 0;
              final h = int.tryParse(hargaCtrl.text.trim()) ?? l.harga;
              if (q <= 0) {
                pesan(ctx, 'Jumlah harus lebih dari 0.', galat: true);
                return;
              }
              Navigator.pop(
                ctx,
                ItemNota(
                  id: edit?.id,
                  nama: l.nama,
                  satuan: l.satuan,
                  qty: q,
                  harga: h,
                ),
              );
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  } finally {
    qtyCtrl.dispose();
    hargaCtrl.dispose();
  }
}

/// Dialog baris bebas yang tidak terikat daftar layanan: tambah pemutih,
/// hutang, saldo titipan, ongkos antar, potongan harga. Satuannya diketik
/// sendiri dan boleh dikosongkan, harganya boleh minus untuk pengurangan.
/// Mengembalikan null bila dibatalkan.
Future<ItemNota?> dialogItemManual(
  BuildContext context, {
  ItemNota? edit,
}) async {
  final namaCtrl = TextEditingController(text: edit?.nama ?? '');
  final qtyCtrl =
      TextEditingController(text: edit == null ? '1' : qtyStr(edit.qty));
  final satuanCtrl = TextEditingController(text: edit?.satuan ?? '');
  final hargaCtrl =
      TextEditingController(text: edit == null ? '' : edit.harga.toString());

  try {
    return await showDialog<ItemNota>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(edit == null ? 'Item Manual' : 'Ubah Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: namaCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: hiasanWajib(
                  label: 'Nama',
                  hint: 'Tambah Pemutih / Hutang / Saldo',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qtyCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: hiasanWajib(label: 'Jumlah'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: satuanCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Satuan',
                        hintText: 'botol, paket',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Satuan boleh dikosongkan, misalnya untuk hutang atau saldo.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: hargaCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(signed: true),
                decoration: hiasanWajib(
                  label: 'Harga satuan',
                  prefix: 'Rp ',
                  bantuan: 'Boleh minus untuk potongan, contoh -5000',
                ),
              ),
              TombolNol(controller: hargaCtrl),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final nama = namaCtrl.text.trim();
              final q = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 0;
              final h = int.tryParse(hargaCtrl.text.trim()) ?? 0;
              if (nama.isEmpty) {
                pesan(ctx, 'Nama item belum diisi.', galat: true);
                return;
              }
              if (q <= 0) {
                pesan(ctx, 'Jumlah harus lebih dari 0.', galat: true);
                return;
              }
              Navigator.pop(
                ctx,
                ItemNota(
                  id: edit?.id,
                  nama: nama,
                  satuan: satuanCtrl.text.trim(),
                  qty: q,
                  harga: h,
                ),
              );
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  } finally {
    namaCtrl.dispose();
    qtyCtrl.dispose();
    satuanCtrl.dispose();
    hargaCtrl.dispose();
  }
}
