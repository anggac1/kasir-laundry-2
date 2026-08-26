import 'package:flutter/material.dart';

import '../models/models.dart';
import '../utils/fmt.dart';

/// Lembar bawah untuk memilih satu layanan. Mengembalikan null bila ditutup.
Future<Layanan?> pilihLayananSheet(
  BuildContext context,
  List<Layanan> layanan,
) {
  return showModalBottomSheet<Layanan>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PilihLayananSheet(layanan: layanan),
  );
}

class _PilihLayananSheet extends StatefulWidget {
  final List<Layanan> layanan;

  const _PilihLayananSheet({required this.layanan});

  @override
  State<_PilihLayananSheet> createState() => _PilihLayananSheetState();
}

class _PilihLayananSheetState extends State<_PilihLayananSheet> {
  String _cari = '';

  @override
  Widget build(BuildContext context) {
    final data = widget.layanan
        .where((l) => l.nama.toLowerCase().contains(_cari.toLowerCase()))
        .toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (_, controller) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              autofocus: false,
              onChanged: (v) => setState(() => _cari = v),
              decoration: const InputDecoration(
                hintText: 'Cari layanan',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: controller,
              itemCount: data.length,
              itemBuilder: (_, i) {
                final l = data[i];
                return ListTile(
                  leading: CircleAvatar(
                    child: Icon(l.satuan == Satuan.kg
                        ? Icons.scale_outlined
                        : Icons.checkroom_outlined),
                  ),
                  title: Text(l.nama),
                  subtitle: Text('${rupiah(l.harga)} / ${l.satuan}'),
                  onTap: () => Navigator.pop(context, l),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
