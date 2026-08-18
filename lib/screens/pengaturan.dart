import 'package:flutter/material.dart';

import '../db/db.dart';
import '../store/settings.dart';
import 'debug_screen.dart';
import 'ekspor_screen.dart';
import 'printer_setup.dart';

class PengaturanScreen extends StatefulWidget {
  const PengaturanScreen({super.key});

  @override
  State<PengaturanScreen> createState() => _PengaturanScreenState();
}

class _PengaturanScreenState extends State<PengaturanScreen> {
  final s = Settings.instance;

  Future<void> _editTeks({
    required String judul,
    required String nilai,
    required Future<void> Function(String) simpan,
    String? bantuan,
    TextInputType tipe = TextInputType.text,
  }) async {
    final ctrl = TextEditingController(text: nilai);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(judul),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: tipe,
          decoration: InputDecoration(helperText: bantuan),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Simpan')),
        ],
      ),
    );
    if (ok == true) {
      await simpan(ctrl.text.trim());
      if (mounted) setState(() {});
    }
  }

  Future<void> _tambahField() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Field Tambahan Baru'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nama field',
            hintText: 'Parfum',
            helperText: 'Placeholder dibuat otomatis dari nama ini',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Tambah')),
        ],
      ),
    );
    if (ok != true) return;

    final nama = ctrl.text.trim();
    if (nama.isEmpty) return;

    final daftar = [...s.fieldTambahan];
    final kunciBaru = Settings.kunciField(nama);
    final bentrok =
        daftar.any((f) => Settings.kunciField(f) == kunciBaru);
    if (bentrok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Placeholder {$kunciBaru} sudah dipakai.')),
        );
      }
      return;
    }

    daftar.add(nama);
    await s.setFieldTambahan(daftar);
    if (mounted) setState(() {});
  }

  Future<void> _hapusField(String nama) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus field "$nama"?'),
        content: const Text(
            'Nota lama tidak berubah, isian yang sudah tersimpan tetap ada '
            'di dalamnya. Hanya kolom isian di nota baru yang hilang.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final daftar = [...s.fieldTambahan]..remove(nama);
    await s.setFieldTambahan(daftar);
    if (mounted) setState(() {});
  }

  Future<void> _hapusSemua() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus semua nota?'),
        content: const Text(
            'Seluruh nota dan riwayat transaksi akan dihapus permanen dari HP ini. '
            'Daftar layanan dan pengaturan tetap aman.\n\n'
            'Tidak ada cadangan di server, jadi data TIDAK bisa dikembalikan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus Semua'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await DB.instance.kosongkanTransaksi();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Semua nota dihapus.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        children: [
          _judul('Identitas Laundry'),
          ListTile(
            leading: const Icon(Icons.storefront_outlined),
            title: const Text('Nama laundry'),
            subtitle: Text(s.namaToko),
            onTap: () => _editTeks(
              judul: 'Nama laundry',
              nilai: s.namaToko,
              simpan: s.setNamaToko,
              bantuan: 'Dipakai placeholder {nama_toko}',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.place_outlined),
            title: const Text('Alamat'),
            subtitle: Text(s.alamatToko),
            onTap: () => _editTeks(
              judul: 'Alamat',
              nilai: s.alamatToko,
              simpan: s.setAlamatToko,
              bantuan: 'Dipakai placeholder {alamat_toko}',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.phone_outlined),
            title: const Text('Telepon / WA'),
            subtitle: Text(s.teleponToko),
            onTap: () => _editTeks(
              judul: 'Telepon / WA',
              nilai: s.teleponToko,
              simpan: s.setTeleponToko,
              bantuan: 'Dipakai placeholder {telepon_toko}',
              tipe: TextInputType.phone,
            ),
          ),
          const Divider(),
          _judul('Printer'),
          ListTile(
            leading: const Icon(Icons.bluetooth),
            title: const Text('Pilih printer'),
            subtitle: Text(s.printerNama ?? 'Belum dipilih'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrinterSetupScreen()),
              );
              if (mounted) setState(() {});
            },
          ),
          ListTile(
            leading: const Icon(Icons.straighten),
            title: const Text('Lebar kertas'),
            subtitle: Text(s.lebarKertas == 32
                ? '58mm  (32 karakter)'
                : '80mm  (48 karakter)'),
            trailing: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 32, label: Text('58mm')),
                ButtonSegment(value: 48, label: Text('80mm')),
              ],
              selected: {s.lebarKertas},
              onSelectionChanged: (v) async {
                await s.setLebarKertas(v.first);
                if (mounted) setState(() {});
              },
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.text_decrease),
            value: s.fontKecil,
            title: const Text('Font kecil (Font B)'),
            subtitle: const Text(
                'Huruf lebih rapat, muat 42 karakter per baris. '
                'Ingat ubah juga Lebar kertas jadi 42.'),
            onChanged: (v) async {
              await s.setFontKecil(v);
              if (mounted) setState(() {});
            },
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Pakai profil RPP02N'),
            subtitle: const Text(
                'Setel otomatis: 58mm, 32 karakter, Font A, tanpa pisau potong'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await s.terapkanProfilRpp02n();
              if (!mounted) return;
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profil RPP02N diterapkan.')),
              );
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.content_cut),
            value: s.potongKertas,
            title: const Text('Potong kertas otomatis'),
            subtitle: const Text(
                'Nyalakan hanya bila printer punya pisau pemotong'),
            onChanged: (v) async {
              await s.setPotongKertas(v);
              if (mounted) setState(() {});
            },
          ),
          ListTile(
            leading: const Icon(Icons.height),
            title: const Text('Baris kosong di akhir struk'),
            subtitle: Text('${s.barisKosongAkhir} baris'),
            onTap: () => _editTeks(
              judul: 'Baris kosong di akhir',
              nilai: s.barisKosongAkhir.toString(),
              tipe: TextInputType.number,
              bantuan: 'Agar struk mudah disobek, biasanya 3-5',
              simpan: (v) => s.setBarisKosongAkhir(
                  int.tryParse(v) ?? s.barisKosongAkhir),
            ),
          ),
          const Divider(),
          _judul('Salinan Struk'),
          ListTile(
            leading: const Icon(Icons.copy_all_outlined),
            title: const Text('Jumlah lembar bawaan'),
            subtitle: Text(s.jumlahSalinan == 1
                ? '1 lembar, bisa ditimpa per nota'
                : '${s.jumlahSalinan} lembar, bisa ditimpa per nota'),
            trailing: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('1')),
                ButtonSegment(value: 2, label: Text('2')),
                ButtonSegment(value: 3, label: Text('3')),
              ],
              selected: {s.jumlahSalinan.clamp(1, 3)},
              onSelectionChanged: (v) async {
                await s.setJumlahSalinan(v.first);
                if (mounted) setState(() {});
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.label_outline),
            title: const Text('Judul tiap salinan'),
            subtitle: Text(s.labelSalinan),
            onTap: () => _editTeks(
              judul: 'Judul tiap salinan',
              nilai: s.labelSalinan,
              simpan: s.setLabelSalinan,
              bantuan: 'Pisahkan dengan koma. Dipakai placeholder {salinan}',
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Ini hanya nilai bawaan. Tiap nota punya kolom "Jumlah lembar '
              'dicetak" sendiri yang menimpanya, jadi Anda bisa mencetak '
              '1 lembar untuk satu pelanggan dan 2 lembar untuk yang lain '
              'tanpa mengubah setelan ini.\n\n'
              'Lembar pertama memakai judul pertama, lembar kedua memakai '
              'judul kedua, dan seterusnya. Letakkan {salinan} di template '
              'struk agar judulnya ikut tercetak.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),

          const Divider(),
          _judul('Field Tambahan'),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Buat kolom isian sendiri, misalnya Parfum atau Jenis Cucian. '
              'Kolomnya muncul saat membuat nota, dan otomatis jadi '
              'placeholder yang bisa dipasang di template struk.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          ...s.fieldTambahan.map(
            (f) => ListTile(
              dense: true,
              leading: const Icon(Icons.short_text),
              title: Text(f),
              subtitle: Text('{${Settings.kunciField(f)}}',
                  style: const TextStyle(fontFamily: 'monospace')),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _hapusField(f),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: OutlinedButton.icon(
              onPressed: _tambahField,
              icon: const Icon(Icons.add),
              label: const Text('Tambah Field'),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44)),
            ),
          ),

          const Divider(),
          _judul('Nota'),
          ListTile(
            leading: Icon(s.pakaiEstimasi ? Icons.login : Icons.check_circle_outline),
            title: const Text('Kebiasaan nota'),
            subtitle: Text(s.pakaiEstimasi
                ? 'Nota di awal, pakai estimasi selesai'
                : 'Nota di akhir, tanpa estimasi'),
            trailing: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Awal')),
                ButtonSegment(value: false, label: Text('Akhir')),
              ],
              selected: {s.pakaiEstimasi},
              onSelectionChanged: (v) async {
                await s.setPakaiEstimasi(v.first);
                if (mounted) setState(() {});
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Hanya nilai bawaan. Tiap nota tetap punya pilihan sendiri, '
              'jadi Anda bisa mencampur keduanya kalau perlu.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.event_outlined),
            title: const Text('Estimasi selesai bawaan'),
            enabled: s.pakaiEstimasi,
            subtitle: Text('${s.estimasiHari} hari setelah nota dibuat'),
            onTap: () => _editTeks(
              judul: 'Estimasi selesai (hari)',
              nilai: s.estimasiHari.toString(),
              tipe: TextInputType.number,
              bantuan: 'Masih bisa diubah per nota',
              simpan: (v) =>
                  s.setEstimasiHari(int.tryParse(v) ?? s.estimasiHari),
            ),
          ),
          const Divider(),
          _judul('Data'),
          const ListTile(
            leading: Icon(Icons.storage_outlined),
            title: Text('Lokasi penyimpanan'),
            subtitle: Text(
                'Semua data tersimpan di HP ini (SQLite). Tidak ada server, '
                'tidak ada akun, tidak ada pengiriman data keluar.'),
            isThreeLine: true,
          ),
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: const Text('Ekspor laporan'),
            subtitle: const Text('Simpan atau kirim laporan sebagai PDF / Excel'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EksporScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Debug'),
            subtitle: const Text(
                'Uji hitung, kode logika, dan byte mentah yang dikirim ke printer'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DebugScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined,
                color: Colors.red),
            title: const Text('Hapus semua nota',
                style: TextStyle(color: Colors.red)),
            subtitle: const Text('Tidak bisa dikembalikan'),
            onTap: _hapusSemua,
          ),
          const Divider(),
          const AboutListTile(
            icon: Icon(Icons.info_outline),
            applicationName: 'Kasir Laundry',
            applicationVersion: '1.0.0',
            applicationLegalese:
                'Aplikasi kasir laundry offline. Seluruh data disimpan lokal '
                'di perangkat dan tidak pernah dikirim ke mana pun.',
            child: Text('Tentang aplikasi'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _judul(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(t,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.grey)),
      );
}
