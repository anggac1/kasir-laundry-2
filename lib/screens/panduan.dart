import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../print/printer_service.dart';
import '../ui/umum.dart';

// Panduan bawaan aplikasi, tiga tab: siapkan dulu, atasi masalah, dan
// pengaturan lanjut. Isinya teks murni supaya ringan dan tetap terbaca
// walau HP sedang tidak ada sinyal.
class PanduanScreen extends StatefulWidget {
  const PanduanScreen({super.key});

  @override
  State<PanduanScreen> createState() => _PanduanScreenState();
}

class _PanduanScreenState extends State<PanduanScreen> {
  // Satu sakelar untuk ketiga tab. Dipakai saat pengguna ingin membaca
  // berurutan tanpa menekan satu per satu.
  bool _semuaTerbuka = false;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Panduan'),
          actions: [
            IconButton(
              onPressed: () => setState(() => _semuaTerbuka = !_semuaTerbuka),
              icon: Icon(_semuaTerbuka
                  ? Icons.unfold_less
                  : Icons.unfold_more),
              tooltip: _semuaTerbuka ? 'Tutup semua' : 'Buka semua',
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(icon: Icon(Icons.rocket_launch_outlined), text: 'Mulai'),
              Tab(icon: Icon(Icons.healing_outlined), text: 'Masalah'),
              Tab(icon: Icon(Icons.tune), text: 'Lanjutan'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ValueKey membuat daftarnya dibangun ulang saat sakelar
            // berubah, jadi keadaan buka/tutupnya ikut menyesuaikan.
            _Isi(_mulai, semua: _semuaTerbuka, key: ValueKey('m$_semuaTerbuka')),
            _Isi(_masalah,
                semua: _semuaTerbuka, key: ValueKey('s$_semuaTerbuka')),
            _Isi(_lanjutan,
                semua: _semuaTerbuka, key: ValueKey('l$_semuaTerbuka')),
          ],
        ),
      ),
    );
  }
}

// Satu butir panduan. Judul selalu ada; sisanya boleh kosong.
class _Butir {
  final String judul;
  final String isi;
  final List<String> langkah;
  final String? catatan;
  final IconData? ikon;

  // Butir yang bisa menghilangkan data. Ditandai merah, bukan hijau,
  // supaya tidak terbaca sekilas sebagai langkah biasa.
  final bool bahaya;

  // Teks yang bisa disalin dengan sekali tekan, misalnya tautan.
  final String? salin;

  const _Butir(
    this.judul, {
    this.isi = '',
    this.langkah = const [],
    this.catatan,
    this.ikon,
    this.bahaya = false,
    this.salin,
  });
}

// Daftar butir panduan. Tiap butir tertutup, isinya baru terbuka saat
// judulnya ditekan, jadi seluruh daftar muat dalam satu layar tanpa
// menggulung panjang.
class _Isi extends StatefulWidget {
  final List<_Butir> butir;
  final bool semua;

  const _Isi(this.butir, {this.semua = false, super.key});

  @override
  State<_Isi> createState() => _IsiState();
}

class _IsiState extends State<_Isi> {
  // Butir mana saja yang sedang terbuka. Boleh lebih dari satu, supaya
  // dua bagian bisa dibandingkan tanpa membuka-tutup terus.
  final Set<int> _terbuka = {};

  @override
  void initState() {
    super.initState();
    if (widget.semua) {
      _terbuka.addAll(List.generate(widget.butir.length, (i) => i));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      itemCount: widget.butir.length,
      itemBuilder: (context, i) {
        final b = widget.butir[i];
        // Merah untuk yang berisiko, hijau untuk yang aman.
        final warna = b.bahaya ? cs.error : cs.primary;
        final latar = b.bahaya ? cs.errorContainer : cs.primaryContainer;
        final atasLatar = b.bahaya ? cs.onErrorContainer : cs.onPrimaryContainer;
        final buka = _terbuka.contains(i);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          color: b.bahaya ? cs.errorContainer.withAlpha(30) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: b.bahaya ? warna.withAlpha(110) : Colors.grey.shade300,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Judul selalu terlihat dan bisa ditekan di seluruh barisnya,
              // bukan hanya pada ikon panahnya.
              InkWell(
                onTap: () => setState(() {
                  if (buka) {
                    _terbuka.remove(i);
                  } else {
                    _terbuka.add(i);
                  }
                }),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (b.ikon != null) ...[
                        Icon(b.ikon, size: 20, color: warna),
                        const SizedBox(width: 10),
                      ],
                      // Judul boleh turun ke baris kedua. Memotongnya dengan
                      // titik tiga justru menyembunyikan isi yang dicari.
                      Expanded(
                        child: Text(
                          b.judul,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: warna,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: buka ? 0.5 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: Icon(Icons.expand_more,
                            size: 22, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),

              // Isi panjang ditaruh di bawah judul, bukan dipadatkan ke
              // samping, supaya tidak ada teks yang terpaksa dipotong.
              if (buka)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (b.isi.isNotEmpty)
                        Text(b.isi,
                            style:
                                const TextStyle(fontSize: 14, height: 1.5)),
                      if (b.langkah.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        for (var j = 0; j < b.langkah.length; j++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  alignment: Alignment.center,
                                  margin:
                                      const EdgeInsets.only(right: 10, top: 1),
                                  decoration: BoxDecoration(
                                    color: latar,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${j + 1}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: atasLatar,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    b.langkah[j],
                                    style: const TextStyle(
                                        fontSize: 14, height: 1.45),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                      if (b.salin != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // Membuka peramban lewat MethodChannel yang
                            // sudah ada. Kalau gagal, tautannya disalin
                            // supaya tetap bisa ditempel sendiri.
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () async {
                                  final ok = await PrinterService.instance
                                      .bukaTautan(b.salin!);
                                  if (!context.mounted) return;
                                  if (!ok) {
                                    await Clipboard.setData(
                                        ClipboardData(text: b.salin!));
                                    if (!context.mounted) return;
                                    pesan(context,
                                        'Peramban tidak terbuka. Tautan '
                                        'sudah disalin, tempel sendiri.');
                                  }
                                },
                                icon: const Icon(Icons.open_in_new, size: 18),
                                label: const Text('Buka'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () async {
                                await Clipboard.setData(
                                    ClipboardData(text: b.salin!));
                                if (!context.mounted) return;
                                pesan(context, 'Tautan disalin.');
                              },
                              icon: const Icon(Icons.copy, size: 18),
                              label: const Text('Salin'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          b.salin!,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ],
                      if (b.catatan != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: latar.withAlpha(b.bahaya ? 90 : 46),
                            borderRadius: BorderRadius.circular(8),
                            border: Border(
                              left: BorderSide(color: warna, width: 3),
                            ),
                          ),
                          child: Text(
                            b.catatan!,
                            style: const TextStyle(fontSize: 13, height: 1.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

const _mulai = <_Butir>[
  _Butir(
    'Cara membaca panduan ini',
    ikon: Icons.info_outline,
    isi: 'Tekan judulnya untuk membuka isi, tekan lagi untuk menutup. Ikon '
        'di kanan atas membuka atau menutup semuanya sekaligus.',
    catatan: 'Butir berjudul hijau aman dicoba kapan saja; kalau salah, '
        'tinggal diubah lagi.\n\n'
        'Butir berjudul MERAH bisa menghilangkan data dan tidak ada tombol '
        'batalnya, jadi baca sampai habis sebelum menekan apa pun.',
  ),
  _Butir(
    'Isi identitas laundry',
    ikon: Icons.storefront_outlined,
    isi: 'Nama, alamat, dan nomor telepon yang tercetak di kepala struk. '
        'Bawaannya masih tulisan contoh, jadi ganti dulu sebelum mencetak '
        'untuk pelanggan.',
    langkah: [
      'Buka menu titik tiga, pilih Pengaturan',
      'Isi Nama, Alamat, dan Telepon laundry Anda',
    ],
  ),
  _Butir(
    'Sesuaikan daftar layanan',
    ikon: Icons.local_offer_outlined,
    isi: 'Aplikasi datang dengan sepuluh contoh layanan beserta tarifnya. '
        'Itu cuma isian awal, silakan ubah sesuai tarif Anda.',
    langkah: [
      'Menu titik tiga, pilih Daftar Layanan',
      'Ketuk salah satu untuk mengubah nama, satuan, atau harga',
      'Tekan tombol tambah untuk membuat layanan baru',
      'Yang tidak dipakai bisa dinonaktifkan, tidak harus dihapus',
    ],
    catatan: 'Satuan tidak terbatas kg dan pcs. Anda boleh mengetik apa saja '
        'seperti paket, lembar, atau meter, bahkan mengosongkannya.',
  ),
  _Butir(
    'Sambungkan printer',
    ikon: Icons.print_outlined,
    isi: 'Printer harus dipasangkan lewat Setelan Bluetooth HP lebih dulu. '
        'Aplikasi hanya membaca daftar perangkat yang sudah terpasang, '
        'tidak memindai sendiri.',
    langkah: [
      'Nyalakan printer, pastikan kertasnya terpasang',
      'Buka Setelan Bluetooth di HP, pasangkan dengan printer Anda',
      'Kembali ke aplikasi: menu titik tiga, pilih Printer',
      'Tekan Izinkan Bluetooth bila diminta',
      'Pilih printer dari daftar, lalu Tes Cetak Contoh',
    ],
    catatan: 'Yang keluar dari Tes Cetak adalah lembar contoh, bukan struk '
        'sungguhan. Ini sengaja, supaya Anda bisa menguji tanpa perlu '
        'membuat nota dulu.',
  ),
  _Butir(
    'Pilih kebiasaan nota Anda',
    ikon: Icons.event_outlined,
    isi: 'Sebagian laundry mencetak nota di awal saat cucian diterima, '
        'sebagian lagi di akhir saat cucian diambil. Keduanya didukung.',
    langkah: [
      'Pengaturan, bagian Nota, pilih Awal atau Akhir',
      'Kalau memilih Awal, atur juga berapa hari estimasi selesainya',
    ],
    catatan: 'Ini hanya nilai bawaan. Tiap nota tetap punya tombolnya '
        'sendiri, jadi Anda bisa mencampur keduanya kalau perlu.',
  ),
  _Butir(
    'Buat nota pertama',
    ikon: Icons.receipt_long_outlined,
    langkah: [
      'Tekan tombol Nota Baru di beranda',
      'Isi nama pelanggan',
      'Tekan Daftar untuk memilih layanan, lalu isi beratnya',
      'Tekan Manual untuk baris tanpa tarif tetap seperti hutang atau saldo',
      'Tekan Pratinjau & Cetak, periksa tampilannya, lalu Cetak',
    ],
    catatan: 'Pratinjau selalu muncul sebelum mencetak. Biasakan membacanya '
        'sekilas — jauh lebih murah daripada mencetak ulang.',
  ),
  _Butir(
    'Yang wajib diisi, dan yang tidak',
    ikon: Icons.check_circle_outline,
    isi: 'Isian wajib ditandai bintang merah, seperti di formulir online. '
        'Sisanya boleh dilewati, dan baris yang kosong tidak akan tercetak '
        'di struk sehingga kertas tidak terbuang.',
    catatan: 'WAJIB\n'
        '  Nama pelanggan\n'
        '  Minimal satu baris item\n\n'
        'OPSIONAL, kosongkan bila tidak perlu\n'
        '  Uang diterima — kosong berarti baris Tunai dan Kembali hilang '
        'dari struk\n'
        '  Status bayar — pilih Sembunyi agar barisnya tidak tercetak sama '
        'sekali\n'
        '  Estimasi selesai — matikan bila nota dicetak saat cucian sudah '
        'diambil\n'
        '  Catatan — tercetak sebagai tanda hubung bila dikosongkan\n'
        '  Jumlah lembar — kosong berarti mengikuti setelan di Pengaturan\n'
        '  Satuan pada baris manual — boleh dikosongkan untuk hutang atau '
        'saldo',
  ),
];

const _masalah = <_Butir>[
  _Butir(
    'Printer tidak muncul di daftar',
    ikon: Icons.bluetooth_disabled,
    isi: 'Aplikasi hanya menampilkan perangkat yang sudah dipasangkan di '
        'HP. Kalau daftarnya kosong, pemasangannya yang belum selesai.',
    langkah: [
      'Buka Setelan Bluetooth di HP',
      'Pastikan printer Anda ada di daftar perangkat tersambung',
      'Kalau belum ada, nyalakan printer lalu pasangkan dari sana',
      'Kembali ke aplikasi, tekan ikon segarkan di pojok kanan atas',
    ],
  ),
  _Butir(
    'Gagal menyambung padahal printer menyala',
    ikon: Icons.link_off,
    isi: 'Printer thermal murah sering melaporkan masih tersambung padahal '
        'sambungannya sudah putus. Aplikasi sudah mencoba tiga kali sebelum '
        'menyerah.',
    langkah: [
      'Matikan printer, tunggu lima detik, nyalakan lagi',
      'Pastikan tidak ada aplikasi lain yang sedang memakai printer',
      'Coba cetak lagi',
    ],
    catatan: 'Kalau muncul dialog Cetak Gagal, di dalamnya ada rincian tiap '
        'langkah. Bagian itu yang menunjukkan di mana persisnya berhenti.',
  ),
  _Butir(
    'Printer bermasalah pas mau mencetak',
    ikon: Icons.print_disabled,
    isi: 'Sudah mengisi nota, tekan cetak, ternyata Bluetooth mati atau '
        'printer tidak menyambung. Nota tidak akan hilang.',
    langkah: [
      'Nota sudah tersimpan otomatis sebelum mencetak',
      'Di dialog yang muncul, tekan Setelan Bluetooth',
      'Nyalakan Bluetooth atau pasangkan printernya',
      'Tekan tombol kembali di HP',
      'Tekan Coba Cetak Lagi, tanpa mengisi ulang apa pun',
    ],
    catatan: 'Kalau memilih Nanti Saja, notanya tetap tersimpan dan bisa '
        'dicetak kapan saja dari daftar di beranda.',
  ),
  _Butir(
    'Satu baris jadi dua baris di kertas',
    ikon: Icons.wrap_text,
    isi: 'Di layar terlihat muat, tapi di kertas melipat. Penyebabnya '
        'hampir selalu lebar kolom yang kelewat mepet.',
    langkah: [
      'Buka Pengaturan, bagian Printer',
      'Ubah Lebar kertas dari 32 menjadi 31',
      'Cetak ulang nota yang tadi melipat',
      'Kalau masih melipat, turunkan lagi ke 30',
    ],
    catatan: 'Sebagian printer menambah margin kiri sedikit, sehingga kolom '
        'yang benar-benar terpakai kurang dari 32. Menurunkan satu angka '
        'biasanya sudah cukup.',
  ),
  _Butir(
    'Hasil cetak tipis atau pudar',
    ikon: Icons.opacity,
    isi: 'Hampir selalu kertasnya, bukan aplikasinya. Kertas thermal murah '
        'lapisannya tipis, dan yang sudah lama disimpan bisa kehilangan '
        'kepekaannya.',
    langkah: [
      'Coba gulungan kertas baru dari merek lain',
      'Bersihkan kepala printer dengan kapas beralkohol, tunggu kering',
      'Pastikan kertas terpasang lurus dan penutupnya terkunci rapat',
      'Isi ulang baterai printer - daya lemah membuat cetakan pudar',
    ],
    catatan: 'Kalau ada baris yang harus benar-benar terbaca, tebalkan '
        'lewat template struk dengan tag [B]. Huruf tebal dicetak dengan '
        'titik lebih rapat, dan itu satu-satunya cara menghitamkan yang '
        'dikenal hampir semua printer.\n\n'
        'Kertas thermal juga memudar sendiri kena panas dan sinar '
        'matahari. Untuk arsip yang harus awet, simpan berkas PDF-nya '
        'lewat Ekspor laporan, jangan mengandalkan struk kertas.',
  ),
  _Butir(
    'Struk tercetak separuh lalu berhenti',
    ikon: Icons.error_outline,
    isi: 'Sambungannya berhasil, tapi data ditolak di tengah jalan.',
    langkah: [
      'Periksa kertas, mungkin hampir habis',
      'Periksa baterai printer, isi dayanya kalau lemah',
      'Kurangi jumlah lembar cetak untuk sementara',
    ],
  ),
  _Butir(
    'Font B dan lebar kertas',
    ikon: Icons.text_decrease,
    isi: 'Font B membuat huruf lebih rapat, jadi kertas 58mm muat 42 '
        'karakter, bukan 32.',
    catatan: 'Keduanya saling mengikuti, jadi tidak mungkin salah pasangan:'
        '\n\n'
        'Font B dinyalakan  -  lebar jadi 42\n'
        'Font B dimatikan   -  lebar jadi 32\n'
        'Lebar diubah ke 42 -  Font B ikut menyala\n'
        'Lebar selain 42    -  Font B ikut mati\n\n'
        'Font B hanya benar pada 42 kolom. Kalau dibiarkan menyala di lebar '
        'lain, strukmya melipat tanpa sebab yang jelas.\n\n'
        'Keterangan di bawah Lebar kertas menyebut ukuran fisiknya, '
        'misalnya "42 karakter per baris - 58mm, Font B".',
  ),
  _Butir(
    'Huruf besar tidak berfungsi',
    ikon: Icons.format_size,
    isi: 'Tag [H] membuat huruf dua kali lebih besar. Kalau tidak '
        'berpengaruh, biasanya tagnya salah tempat.',
    catatan: 'Tag harus berada di awal baris, sebelum teks apa pun. '
        'Boleh digabung seperti [BCH] untuk tebal, tengah, dan besar '
        'sekaligus. Ingat, huruf besar memakan dua kali lebar, jadi satu '
        'baris hanya muat separuh dari biasanya.',
  ),
  _Butir(
    'Daftar printer lambat muncul',
    ikon: Icons.bluetooth_searching,
    isi: 'Sudah tidak terjadi. Layar Printer langsung menampilkan daftar '
        'perangkat dari pembukaan sebelumnya, tanpa menunggu.',
    catatan: 'Daftar yang sebenarnya menyusul beberapa ratus milidetik '
        'kemudian dan menimpa yang tersimpan. Kalau printer baru saja '
        'dipasangkan di Setelan Bluetooth HP dan belum muncul, tekan ikon '
        'segarkan di kanan atas.',
  ),
  _Butir(
    'Menagih banyak pelanggan sekaligus',
    ikon: Icons.playlist_add_check,
    isi: 'Status bayar bisa diubah langsung dari beranda, tanpa membuka '
        'notanya satu per satu. Berguna saat banyak pelanggan melunasi '
        'berbarengan.',
    langkah: [
      'Di beranda, ketuk kartu hutang di atas untuk menyaring yang belum '
          'bayar saja',
      'Ketuk harga atau lencana BELUM BAYAR di sisi kanan baris',
      'Notanya langsung jadi LUNAS dan hilang dari saringan',
      'Ulangi untuk pelanggan berikutnya',
    ],
    catatan: 'Seluruh sisi kanan baris - angka harga dan lencananya - '
        'adalah satu tombol, jadi tidak perlu membidik lencananya yang '
        'kecil. Menekan sisi kiri baris tetap membuka notanya seperti '
        'biasa.\n\n'
        'Bisa dua arah: mengetuk yang sudah LUNAS mengembalikannya jadi '
        'BELUM BAYAR, untuk berjaga kalau salah tekan.\n\n'
        'Setiap perubahan memunculkan tombol Batal selama beberapa detik '
        'di bawah layar.\n\n'
        'Cara lama lewat halaman detail nota tetap ada, lengkap dengan '
        'kolom uang diterima dan kembalian.',
  ),
  _Butir(
    'Ubah kata pengantar saat mengirim nota',
    ikon: Icons.chat_bubble_outline,
    isi: 'Kalimat yang menemani gambar atau PDF di chat pelanggan bisa '
        'diganti sendiri, misalnya disesuaikan dengan gaya bicara laundry '
        'Anda.',
    langkah: [
      'Menu titik tiga, pilih Template Struk',
      'Buka tab Pengaturan',
      'Ketuk Kata pengantar, lalu tulis kalimatnya',
    ],
    catatan: 'Boleh menyisipkan {nama}, {toko}, {tanggal}, {no_nota}, dan '
        '{total}, yang terisi otomatis sesuai notanya.\n\n'
        'Contoh: "Halo {nama}, terima kasih sudah laundry di {toko}."\n\n'
        'Ini hanya kalimat sapaan. Isi struknya sendiri sudah ada di dalam '
        'gambar atau PDF yang dilampirkan.',
  ),
  _Butir(
    'Beranda terasa lambat dibuka',
    ikon: Icons.hourglass_bottom,
    isi: 'Angka hutang di beranda dihitung dengan membaca setiap nota yang '
        'belum lunas. Setelah notanya menumpuk, itu mulai terasa.',
    langkah: [
      'Buka Pengaturan, bagian Beranda',
      'Ubah Angka hutang dari Auto menjadi Manual',
      'Tombol perbarui akan muncul di beranda',
      'Tekan tombol itu saat memang perlu angka terbaru',
    ],
    catatan: 'Titik kecil di tombol menandakan ada nota yang berubah sejak '
        'terakhir dihitung. Selama nota Anda masih di bawah sekitar 50.000, '
        'biarkan Auto — bedanya tidak akan terasa.',
  ),
  _Butir(
    'Nota belum selesai, terlanjur tertekan Kembali',
    ikon: Icons.history,
    isi: 'Tidak hilang. Isian yang belum disimpan tersimpan otomatis, dan '
        'muncul lagi begitu Nota Baru dibuka.',
    langkah: [
      'Tekan Nota Baru seperti biasa',
      'Isian sebelumnya sudah terisi kembali',
      'Lanjutkan, atau tekan Mulai Baru di spanduk kuning untuk mengosongkan',
    ],
    catatan: 'Yang ikut tersimpan: nama, daftar item, catatan, uang '
        'diterima, estimasi, dan kolom tambahan.\n\n'
        'Drafnya hilang sendiri setelah notanya disimpan, jadi nota '
        'berikutnya selalu mulai kosong.',
  ),
  _Butir(
    'Nota hilang setelah pasang ulang aplikasi',
    ikon: Icons.delete_forever_outlined,
    bahaya: true,
    isi: 'Data tersimpan di dalam aplikasi, bukan di kartu memori. '
        'Mencopot aplikasi berarti menghapus datanya juga.',
    catatan: 'Sebelum mencopot atau memasang versi baru, buka Ekspor lalu '
        'simpan berkas PDF atau Excel-nya ke tempat lain. Itu satu-satunya '
        'cadangan yang ada.',
  ),
];

const _lanjutan = <_Butir>[
  _Butir(
    'Cara kerja template struk',
    ikon: Icons.code,
    isi: 'Teks biasa dicetak apa adanya. Teks dalam kurung kurawal diganti '
        'data nota. Semua bisa Anda ubah lewat menu Template Struk.',
    catatan: 'Tag di awal baris:\n'
        '[L] [C] [R]  rata kiri, tengah, kanan\n'
        '[B]  tebal\n'
        '[H]  huruf dua kali besar\n'
        '[C3] angka berarti ukuran huruf, 1 sampai 8\n\n'
        'Tag di tengah baris:\n'
        '[>]  dorong sisanya ke kanan\n\n'
        'Baris berisi --- menjadi garis pemisah.',
  ),
  _Butir(
    'Mengatur ukuran huruf',
    ikon: Icons.format_size,
    isi: 'Tambahkan angka di dalam tag untuk mengatur besar huruf. Angka 1 '
        'sampai 8, dan 1 berarti ukuran biasa.',
    catatan: '[C1.5]NAMA TOKO    tengah, lebih tinggi, tetap 32 kolom\n'
        '[C2]LAUNDRY JAYA   tengah, dua kali besar\n'
        '[BC3]LUNAS           tebal, tengah, tiga kali\n'
        '[R2]Rp50.000        kanan, dua kali\n\n'
        'Baris tanpa angka tetap berukuran biasa, jadi template lama tidak '
        'perlu diubah. [H] sendiri masih berarti dua kali besar.\n\n'
        'Ingat, huruf makin besar berarti makin sedikit yang muat: pada '
        'kertas 32 kolom, ukuran 2 hanya muat 16 huruf, ukuran 3 muat 10.'
        '\n\n'
        'Butuh yang cuma sedikit lebih besar? Pakai pecahan, misalnya '
        '[C1.5]. Hurufnya jadi dua kali lebih TINGGI tapi lebarnya tetap, '
        'jadi barisnya masih muat 32 huruf penuh.\n\n'
        'Kenapa lebarnya tidak bisa 1,5 kali? Printer thermal hanya '
        'mengenal kelipatan bulat untuk lebar maupun tinggi. Yang bisa '
        'dilakukan adalah menaikkan tingginya saja, dan itulah yang '
        'dikerjakan pecahan di sini.',
  ),
  _Butir(
    'Menyimpan template, lima laci',
    ikon: Icons.folder_open_outlined,
    isi: 'Ikon folder di kanan atas halaman Template Struk. Gunanya '
        'menyimpan template yang sudah jadi, supaya bisa coba-coba tanpa '
        'takut kehilangan yang sekarang dipakai.',
    langkah: [
      'Buka Template Struk, tekan ikon folder di kanan atas',
      'Tekan Simpan pada salah satu laci, lalu beri nama',
      'Untuk memakainya lagi, tekan Pakai pada laci itu',
    ],
    catatan: 'Yang tersimpan adalah isi kotak teks saat itu, termasuk '
        'perubahan yang belum ditekan Simpan.\n\n'
        'Pakai berarti menimpa template yang sedang dibuka, jadi selalu '
        'ada konfirmasi dulu. Tombol tong sampah merah mengosongkan laci, '
        'dan itu tidak mengubah template yang sedang dibuka.',
  ),
  _Butir(
    'Menyembunyikan baris yang kosong',
    ikon: Icons.visibility_off_outlined,
    isi: 'Tag [?kunci] membuat satu baris hanya tercetak kalau isinya ada. '
        'Ini cara menghemat kertas tanpa mengubah apa pun tiap transaksi.',
    catatan: 'Contoh: [?uang]Tunai[>]{uang}\n\n'
        'Baris itu hilang sendiri kalau Anda tidak mengisi uang yang '
        'diterima. Sama untuk [?kembalian], [?estimasi], dan '
        '[?status_bayar].',
  ),
  _Butir(
    'Uang pelanggan kurang dari tagihan',
    ikon: Icons.money_off,
    isi: 'Kalau uang yang diterima lebih kecil daripada total, struk tidak '
        'menulis kembalian bertanda minus. Barisnya berubah sendiri jadi '
        '"Kurang" dengan angka biasa.',
    langkah: [
      'Isi Uang diterima seperti biasa, walau kurang',
      'Struk otomatis menulis "Kurang Rp10.000", bukan "Kembali -Rp10.000"',
      'Kalau uangnya lebih, tulisannya kembali jadi "Kembali"',
    ],
    catatan: 'Di template, kata itu berasal dari {label_kembalian}. Jadi '
        'barisnya ditulis:\n\n'
        '  [?kembalian]{label_kembalian}[>]{kembalian}\n\n'
        'Kalau Anda pernah mengubah template sendiri dan masih mengetik '
        'kata "Kembali" apa adanya, gantilah dengan {label_kembalian} '
        'supaya ikut berubah.\n\n'
        'Ini berbeda dengan SISA SALDO. Sisa saldo berarti pelanggan '
        'menitipkan uang lebih dari tagihan; "Kurang" berarti '
        'pembayarannya belum cukup.',
  ),
  _Butir(
    'Saran nama pelanggan',
    ikon: Icons.person_search_outlined,
    isi: 'Mengetik nama akan memunculkan saran dari nota yang pernah dibuat, '
        'jadi pelanggan langganan tidak perlu diketik ulang.',
    catatan: 'Kalau ada nama yang salah ketik dan mengganggu, tekan silang '
        'di sebelah kanannya. Nama itu tidak disarankan lagi, tapi notanya '
        'tetap utuh dan tetap bisa dicari di beranda.\n\n'
        'Untuk mengembalikan semuanya: Pengaturan, bagian Beranda, '
        'Saran nama pelanggan, tekan Tampilkan.',
  ),
  _Butir(
    'Membuat field sendiri',
    ikon: Icons.add_box_outlined,
    isi: 'Kalau Anda perlu mencatat sesuatu yang belum ada, misalnya jenis '
        'parfum atau nama pengantar, buat field baru.',
    langkah: [
      'Pengaturan, bagian Field Tambahan, tekan Tambah Field',
      'Ketik namanya, misalnya Parfum',
      'Buka Template Struk, sisipkan {parfum} di tempat yang diinginkan',
      'Field baru itu muncul sendiri saat membuat nota',
    ],
    catatan: 'Nama field diubah otomatis jadi huruf kecil dengan garis '
        'bawah. "Jenis Cucian" menjadi {jenis_cucian}.',
  ),
  _Butir(
    'Dua lembar dengan judul berbeda',
    ikon: Icons.content_copy_outlined,
    isi: 'Struk bisa dicetak beberapa lembar sekaligus, masing-masing '
        'dengan judul sendiri, misalnya satu untuk pelanggan dan satu untuk '
        'arsip toko.',
    langkah: [
      'Pengaturan, bagian Salinan Struk, atur jumlah lembar',
      'Isi Judul salinan, dipisah koma: PELANGGAN,ARSIP TOKO',
      'Di template, {salinan} akan terisi judul yang sesuai tiap lembar',
    ],
    catatan: 'Tiap nota juga bisa punya jumlah lembarnya sendiri, diatur '
        'dari halaman detail nota. Kosongkan untuk mengikuti bawaan ini.',
  ),
  _Butir(
    'Saldo titipan dan hutang',
    ikon: Icons.account_balance_wallet_outlined,
    isi: 'Baris manual bisa diisi angka negatif. Ini cara mencatat titipan '
        'uang pelanggan tanpa perlu fitur terpisah.',
    catatan: 'Kalau titipan lebih besar daripada tagihan, totalnya jadi '
        'negatif. Struk otomatis mencetaknya sebagai angka positif dengan '
        'tulisan SISA SALDO, bukan TOTAL bertanda minus.',
  ),
  _Butir(
    'Menyimpan rekap',
    ikon: Icons.download_outlined,
    isi: 'Ekspor menghasilkan berkas PDF untuk dibaca dan Excel untuk '
        'diolah lagi.',
    langkah: [
      'Menu titik tiga, pilih Pengaturan, lalu Ekspor laporan',
      'Pilih rentang waktunya',
      'Tekan PDF atau Excel',
    ],
    catatan: 'Biasakan mengekspor sebelum memasang versi baru aplikasi. '
        'Data nota ikut terhapus saat aplikasi dicopot.',
  ),
  _Butir(
    'Tombol +000 dan papan ketik',
    ikon: Icons.keyboard_outlined,
    isi: 'Di setiap kolom harga ada satu tombol +000. Ketik 7 lalu tekan '
        'tombol itu untuk mendapat 7000, tanpa perlu menghitung nolnya.',
    catatan: 'Hanya +000 yang disediakan. Angka 0 dan tombol hapus sudah ada '
        'di papan ketik bawaan HP, jadi tidak diulang di layar.\n\n'
        'Kolom Nama Pelanggan memakai papan ketik yang huruf awal tiap katanya '
        'otomatis besar. Kolom Catatan hanya membesarkan huruf pertama '
        'kalimat dan huruf setelah titik. Keduanya cuma saran papan ketik, '
        'jadi Anda tetap bebas mengetik huruf kecil.',
  ),
  _Butir(
    'Menghapus nota',
    ikon: Icons.delete_outline,
    bahaya: true,
    isi: 'Nota yang dihapus tidak bisa dikembalikan. Tidak ada tempat sampah '
        'dan tidak ada tombol urungkan.',
    langkah: [
      'Buka nota yang dimaksud dari beranda',
      'Tekan ikon tong sampah di kanan atas',
      'Baca nama dan nomor notanya, pastikan benar, lalu tekan Hapus',
    ],
    catatan: 'Kalau notanya cuma salah isi, lebih aman diubah daripada '
        'dihapus. Total harian ikut berubah begitu nota dihapus, jadi rekap '
        'kemarin bisa berbeda dari yang sudah Anda catat.',
  ),
  _Butir(
    'Mencopot aplikasi atau menghapus datanya',
    ikon: Icons.dangerous_outlined,
    bahaya: true,
    isi: 'Semua nota tersimpan di dalam aplikasi, bukan di kartu memori dan '
        'bukan di server. Mencopot aplikasi atau menekan Hapus Data di '
        'setelan HP akan menghapus seluruh riwayat sekaligus.',
    langkah: [
      'Ekspor dulu: Pengaturan, Ekspor laporan, pilih rentang paling awal',
      'Simpan berkas PDF dan Excel-nya ke tempat lain, bukan di HP itu saja',
      'Baru copot atau pasang versi barunya',
    ],
    catatan: 'Memperbarui aplikasi DI ATAS yang lama aman, datanya ikut. '
        'Yang menghapus data adalah mencopot lebih dulu lalu memasang '
        'ulang.',
  ),
  _Butir(
    'Bagikan nota ke pelanggan',
    ikon: Icons.share_outlined,
    isi: 'Nota bisa dikirim ke pelanggan tanpa dicetak. Tombolnya ada di '
        'halaman detail nota, di bawah Cetak Struk.',
    langkah: [
      'Buka notanya dari beranda',
      'Tekan Bagikan ke Pelanggan',
      'Buka tab Teks, Gambar, atau PDF untuk melihat hasilnya',
      'Tekan tombol Bagikan di bawah - yang terkirim bentuk yang '
          'sedang Anda lihat',
      'Pilih aplikasi tujuannya di menu berbagi bawaan HP',
    ],
    catatan: 'Teks   - langsung terbaca di chat, tapi ukuran huruf tidak '
        'ikut karena WhatsApp tidak mengenalnya\n'
        'PDF    - rapi, bisa dicetak ulang pelanggan\n'
        'Gambar - paling mirip struk asli, ukuran huruf ikut terlihat\n\n'
        'Yang dikirim satu bentuk saja, yaitu tab yang sedang dibuka. '
        'Layar pratinjau menampilkannya apa adanya sebelum dikirim, jadi '
        'tidak perlu menebak hasilnya.\n\n'
        'Tidak ada nomor WhatsApp yang perlu diisi: berkasnya diserahkan '
        'ke menu berbagi bawaan HP.',
  ),
  _Butir(
    'Kiat memakai kertas lebih hemat',
    ikon: Icons.eco_outlined,
    isi: 'Beberapa hal kecil yang menghemat lumayan kalau dihitung sebulan:',
    langkah: [
      'Pakai [?kunci] pada baris yang tidak selalu terisi',
      'Kurangi baris kosong di akhir struk, cukup 3 sampai 4',
      'Pilih Sembunyi pada status bayar bila tidak perlu dicetak',
      'Cetak satu lembar saja kalau arsip toko tidak dibutuhkan',
    ],
  ),
  _Butir(
    'Dukungan sukarela',
    ikon: Icons.volunteer_activism_outlined,
    isi: 'Aplikasi ini gratis sepenuhnya. Tidak ada masa coba, tidak ada '
        'fitur terkunci, tidak ada iklan, dan tidak ada data yang dikirim '
        'ke mana pun.',
    salin: 'https://saweria.co/qlc20',
    catatan: 'Kalau merasa terbantu dan ingin memberi dukungan, tekan '
        'tombol di atas untuk menyalin tautannya, lalu buka di peramban.\n\n'
        'Sepenuhnya sukarela. Tidak memberi apa pun tidak mengurangi satu '
        'fitur pun, dan tidak ada yang terkunci.',
  ),
];
