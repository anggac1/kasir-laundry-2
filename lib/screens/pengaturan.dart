import 'package:flutter/material.dart';

import '../db/db.dart';
import '../store/settings.dart';
import '../ui/umum.dart';
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
    final hasil = await dialogIsian(
      context,
      judul: judul,
      awal: nilai,
      bantuan: bantuan,
      tipe: tipe,
    );
    if (hasil == null) return;
    await simpan(hasil.trim());
    if (mounted) setState(() {});
  }

  Future<void> _tambahField() async {
    final hasil = await dialogIsian(
      context,
      judul: 'Field Tambahan Baru',
      label: 'Nama field',
      bantuan: 'Placeholder dibuat otomatis dari nama ini',
    );
    if (hasil == null) return;

    final nama = hasil.trim();
    if (nama.isEmpty) return;

    final daftar = [...s.fieldTambahan];
    final kunciBaru = Settings.kunciField(nama);
    if (daftar.any((f) => Settings.kunciField(f) == kunciBaru)) {
      if (mounted) {
        pesan(context, 'Placeholder {$kunciBaru} sudah dipakai.', galat: true);
      }
      return;
    }

    daftar.add(nama);
    await s.setFieldTambahan(daftar);
    if (mounted) setState(() {});
  }

  Future<void> _hapusField(String nama) async {
    final ok = await konfirmasiHapus(
      context,
      judul: 'Hapus field "$nama"?',
      isi: 'Nota lama tidak berubah, isian yang sudah tersimpan tetap ada '
          'di dalamnya. Hanya kolom isian di nota baru yang hilang.',
    );
    if (!ok) return;
    final daftar = [...s.fieldTambahan]..remove(nama);
    await s.setFieldTambahan(daftar);
    if (mounted) setState(() {});
  }

  Future<void> _hapusSemua() async {
    final ok = await konfirmasiHapus(
      context,
      judul: 'Hapus semua nota?',
      isi: 'Seluruh nota dan riwayat transaksi akan dihapus permanen dari '
          'HP ini. Daftar layanan dan pengaturan tetap aman.\n\n'
          'Tidak ada cadangan di server, jadi data TIDAK bisa dikembalikan.',
      tombol: 'Hapus Semua',
    );
    if (!ok) return;
    await DB.instance.kosongkanTransaksi();
    if (!mounted) return;
    pesan(context, 'Semua nota dihapus.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        children: [
          _seksi('Identitas Laundry'),
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
          _seksi('Printer'),
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
            subtitle: Text('${s.lebarKertas} karakter per baris'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  tooltip: 'Kurangi satu',
                  onPressed: s.lebarKertas <= kLebarMin
                      ? null
                      : () async {
                          await s.setLebarKertas(s.lebarKertas - 1);
                          if (mounted) setState(() {});
                        },
                ),
                Text('${s.lebarKertas}',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Tambah satu',
                  onPressed: s.lebarKertas >= kLebarMaks
                      ? null
                      : () async {
                          await s.setLebarKertas(s.lebarKertas + 1);
                          if (mounted) setState(() {});
                        },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Patokan: 58mm = 32, 80mm = 48. Kalau baris yang di layar '
                  'terlihat muat ternyata melipat di kertas, turunkan satu '
                  'angka jadi 31, lalu 30 bila masih melipat.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final n in const [30, 31, 32, 42, 48])
                      ActionChip(
                        label: Text('$n'),
                        onPressed: () async {
                          await s.setLebarKertas(n);
                          if (mounted) setState(() {});
                        },
                      ),
                  ],
                ),
              ],
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
            title: const Text('Kembalikan ke setelan bawaan'),
            subtitle: const Text(
                'Bawaan: 58mm, 32 karakter, Font A, tanpa pisau potong. '
                'Cocok untuk RPP02N.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await s.resetPrinter();
              if (!mounted) return;
              setState(() {});
              pesan(context, 'Setelan printer dikembalikan ke bawaan.');
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
              simpan: (v) =>
                  s.setBarisKosongAkhir(int.tryParse(v) ?? s.barisKosongAkhir),
            ),
          ),
          const Divider(),
          _seksi('Salinan Struk'),
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
          _seksi('Field Tambahan'),
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
          _seksi('Nota'),
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
          _seksi('Beranda'),
          ListTile(
            leading: Icon(s.hutangOtomatis ? Icons.autorenew : Icons.touch_app_outlined),
            title: const Text('Angka hutang di beranda'),
            subtitle: Text(s.hutangOtomatis
                ? 'Dihitung ulang sendiri setiap ada nota berubah'
                : 'Ditekan sendiri lewat tombol perbarui di beranda'),
            trailing: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Auto')),
                ButtonSegment(value: false, label: Text('Manual')),
              ],
              selected: {s.hutangOtomatis},
              onSelectionChanged: (v) async {
                await s.setHutangOtomatis(v.first);
                if (mounted) setState(() {});
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Menghitung angka hutang berarti membaca setiap nota yang '
              'belum lunas, jadi makin lama makin berat. Selama nota Anda '
              'masih di bawah sekitar 50.000, biarkan Auto — bedanya tidak '
              'terasa. Kalau sudah menumpuk dan beranda mulai lambat dibuka, '
              'pindah ke Manual. Tombol perbarui akan muncul di beranda, '
              'dengan titik kecil saat angkanya sudah berubah.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person_search_outlined),
            title: const Text('Saran nama pelanggan'),
            subtitle: Text(s.namaDisembunyikan.isEmpty
                ? 'Semua nama disarankan'
                : '${s.namaDisembunyikan.length} nama disembunyikan'),
            trailing: s.namaDisembunyikan.isEmpty
                ? null
                : TextButton(
                    onPressed: () async {
                      await s.tampilkanSemuaNama();
                      if (!mounted) return;
                      setState(() {});
                      pesan(context, 'Semua nama disarankan lagi.');
                    },
                    child: const Text('Tampilkan'),
                  ),
          ),
          const Divider(),
          _seksi('Data'),
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

  // JudulSeksi berpadding kecil, digeser agar sejajar dengan ListTile.
  Widget _seksi(String teks) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: JudulSeksi(teks),
      );
}
