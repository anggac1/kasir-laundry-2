import 'package:flutter/material.dart';

import '../store/settings.dart';
import '../ui/umum.dart';
import 'ekspor_screen.dart';
import 'hapus_data.dart';

// Nama tingkat ketebalan untuk mode cetak gambar.
const _namaTebalGambar = ['Apa adanya', 'Tebal', 'Lebih tebal', 'Paling tebal'];



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

  // #Mengubah lebar kertas, sekaligus menjaga Font B tetap masuk akal
  //
  // Font B hanya benar pada 42 kolom. Lebar berapa pun selain itu berarti
  // Font A, jadi sakelarnya dimatikan sendiri daripada dibiarkan menyala
  // dan membuat struk melipat tanpa sebab yang jelas.
  Future<void> _ubahLebar(int lebar) async {
    final s = Settings.instance;
    final fontBSebelum = s.fontKecil;
    await s.setLebarKertas(lebar);
    if (lebar == 42 && !s.fontKecil) {
      await s.setFontKecil(true);
    } else if (lebar != 42 && s.fontKecil) {
      await s.setFontKecil(false);
    }
    if (!mounted) return;
    setState(() {});
    if (fontBSebelum != s.fontKecil) {
      pesan(context,
          s.fontKecil ? 'Font B ikut dinyalakan.' : 'Font B ikut dimatikan.');
    }
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
          _seksi('Kertas dan Huruf'),
          ListTile(
            leading: const Icon(Icons.straighten),
            title: const Text('Lebar kertas'),
            subtitle: Text('${s.lebarKertas} karakter per baris  -  '
                '${s.keteranganKertas}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  tooltip: 'Kurangi satu',
                  onPressed: s.lebarKertas <= kLebarMin
                      ? null
                      : () => _ubahLebar(s.lebarKertas - 1),
                ),
                Text('${s.lebarKertas}',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Tambah satu',
                  onPressed: s.lebarKertas >= kLebarMaks
                      ? null
                      : () => _ubahLebar(s.lebarKertas + 1),
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
                  'Patokan Font A: 58mm = 32, 80mm = 48. '
                  'Font B: 58mm = 42.\n'
                  'Kalau baris yang di layar terlihat muat ternyata melipat '
                  'di kertas, turunkan satu angka jadi 31, lalu 30.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final n in const [30, 31, 32, 42, 48])
                      ActionChip(
                        label: Text('$n'),
                        onPressed: () => _ubahLebar(n),
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
            subtitle: Text(s.fontKecil
                ? 'Aktif. Huruf lebih rapat, kertas 58mm muat 42 karakter.'
                : 'Huruf lebih rapat, kertas 58mm muat 42 karakter '
                    'daripada 32.'),
            // Dua arah: menyalakan Font B membawa lebar ke 42, mematikannya
            // mengembalikan ke 32. Arah sebaliknya diurus _ubahLebar.
            onChanged: (v) async {
              await s.setFontKecil(v);
              await s.setLebarKertas(v ? 42 : 32);
              if (!mounted) return;
              setState(() {});
              pesan(
                  context,
                  v
                      ? 'Font B aktif, lebar kertas jadi 42.'
                      : 'Font A aktif, lebar kertas jadi 32.');
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
          const Divider(),
          _seksi('Kalau Hasil Cetak Pudar'),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(
              'Printer 58mm tidak punya setelan kepekatan yang bisa '
              'diatur aplikasi. Dua cara di bawah ini mengakalinya dari '
              'sisi aplikasi. Coba yang pertama dulu - kalau masih pudar, '
              'baru nyalakan yang kedua.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.format_bold),
            value: s.tebalkanSemua,
            title: const Text('Tebalkan semua baris'),
            subtitle: const Text(
                'Seluruh struk dicetak dengan huruf tebal, bukan hanya '
                'baris bertag [B]. Membantu pada kertas yang tipis.'),
            isThreeLine: true,
            onChanged: (v) async {
              await s.setTebalkanSemua(v);
              if (mounted) setState(() {});
            },
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Cara paling ringan. Bandingkan dulu lewat "Uji Ketebalan" '
              'di layar Printer.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const Divider(height: 24),
          SwitchListTile(
            secondary: const Icon(Icons.image_outlined),
            value: s.cetakGambar,
            title: const Text('Cetak sebagai gambar'),
            subtitle: const Text(
                'Struk digambar dulu di HP, baru dikirim sebagai gambar. '
                'Ketebalan hurufnya jadi bisa diatur sendiri.'),
            isThreeLine: true,
            onChanged: (v) async {
              await s.setCetakGambar(v);
              if (mounted) setState(() {});
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dalam mode gambar, aplikasi yang menentukan tiap titik '
                  'yang ditembakkan printer - jadi huruf bisa ditebalkan '
                  'sampai terbaca di kertas yang buruk.\n'
                  'Efek samping: mencetak lebih lambat, dan struk tidak '
                  'bisa disalin sebagai teks oleh printer.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (s.cetakGambar) ...[
                  const SizedBox(height: 10),
                  const Text('Ketebalan huruf',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (var i = 0; i < _namaTebalGambar.length; i++)
                        ChoiceChip(
                          label: Text(_namaTebalGambar[i]),
                          selected: s.tebalGambar == i,
                          onSelected: (_) async {
                            await s.setTebalGambar(i);
                            if (mounted) setState(() {});
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Makin tebal makin hitam, tapi kalau kelewatan huruf '
                    'bisa saling menempel.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  const Text('Tembakan per titik',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (var i = 1; i <= 2; i++)
                        ChoiceChip(
                          label: Text(i == 1 ? 'Sekali' : 'Dua kali'),
                          selected: s.ulangGambar == i,
                          onSelected: (_) async {
                            await s.setUlangGambar(i);
                            if (mounted) setState(() {});
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Dua kali menembak titik yang sama sebelum kertas '
                    'bergerak, jadi panasnya berlipat dan hasilnya paling '
                    'hitam. Ongkosnya: mencetak jadi dua kali lebih lama.\n'
                    'Tekan "Uji Kualitas Cetak" di layar Printer untuk '
                    'melihat semua kombinasi sekaligus.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
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
              'Hanya nilai bawaan. Tiap nota punya kolom "Jumlah lembar '
              'dicetak" sendiri yang menimpanya.\n\n'
              'Judul dipakai berurutan: lembar 1 judul 1, lembar 2 judul 2. '
              'Pasang {salinan} di template agar ikut tercetak.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),

          const Divider(),
          _seksi('Field Tambahan'),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Kolom isian sendiri, misalnya Parfum. Muncul saat membuat '
              'nota, dan jadi placeholder untuk template struk.',
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
              'Menghitung hutang membaca semua nota belum lunas, jadi makin '
              'lama makin berat. Di bawah 50.000 nota, biarkan Auto.\n\n'
              'Kalau beranda mulai lambat, pindah ke Manual. Tombol perbarui '
              'muncul di beranda, bertitik saat angkanya berubah.',
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
          _labelSetelan(
              'Lokasi penyimpanan',
              'Semua data tersimpan di HP ini (SQLite). Tidak ada server, '
              'tidak ada akun, tidak ada pengiriman data keluar.'),
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
          // Satu pintu untuk semua penghapusan, dengan centang.
          //
          // Android cuma punya "hapus cache" yang membabi buta. Di sini
          // pengguna memilih sendiri, jadi membersihkan berkas yang
          // menumpuk tidak harus ikut mengorbankan nota.
          ListTile(
            leading: Icon(Icons.cleaning_services_outlined,
                color: Colors.red.shade700),
            title: Text('Hapus data',
                style: TextStyle(color: Colors.red.shade700)),
            subtitle: const Text(
                'Pilih sendiri: berkas sementara, saran nama, semua nota, '
                'atau setelan'),
            isThreeLine: true,
            onTap: () async {
              await tampilkanHapusData(context);
              if (mounted) setState(() {});
            },
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

  // Keterangan yang memang cuma dibaca, bukan tombol.
  //
  // Dibedakan dari ListTile supaya tidak ada yang mengetuknya lalu
  // bingung kenapa tidak terjadi apa-apa: tanpa ikon, tanpa tanda
  // panah, dan menjorok sejajar dengan keterangan lain.
  Widget _labelSetelan(String judul, String isi) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(judul,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(isi,
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
      );

  // JudulSeksi berpadding kecil, digeser agar sejajar dengan ListTile.
  Widget _seksi(String teks) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: JudulSeksi(teks),
      );
}
