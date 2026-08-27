import 'package:flutter/material.dart';

// Panduan bawaan aplikasi, tiga tab: siapkan dulu, atasi masalah, dan
// pengaturan lanjut. Isinya teks murni supaya ringan dan tetap terbaca
// walau HP sedang tidak ada sinyal.
class PanduanScreen extends StatelessWidget {
  const PanduanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Panduan'),
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
        body: const TabBarView(
          children: [
            _Isi(_mulai),
            _Isi(_masalah),
            _Isi(_lanjutan),
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

  const _Butir(
    this.judul, {
    this.isi = '',
    this.langkah = const [],
    this.catatan,
    this.ikon,
  });
}

class _Isi extends StatelessWidget {
  final List<_Butir> butir;

  const _Isi(this.butir);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: butir.length,
      itemBuilder: (context, i) {
        final b = butir[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (b.ikon != null) ...[
                    Icon(b.ikon, size: 20, color: cs.primary),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      b.judul,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                    ),
                  ),
                ],
              ),
              if (b.isi.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(b.isi, style: const TextStyle(fontSize: 14, height: 1.5)),
              ],
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
                          margin: const EdgeInsets.only(right: 10, top: 1),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${j + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            b.langkah[j],
                            style: const TextStyle(fontSize: 14, height: 1.45),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              if (b.catatan != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withAlpha(46),
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(color: cs.primary, width: 3),
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
        );
      },
    );
  }
}

const _mulai = <_Butir>[
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
      'Kembali ke aplikasi: Pengaturan, lalu Pilih printer',
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
    'Nota hilang setelah pasang ulang aplikasi',
    ikon: Icons.warning_amber_outlined,
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
        '[H]  huruf dua kali besar\n\n'
        'Tag di tengah baris:\n'
        '[>]  dorong sisanya ke kanan\n\n'
        'Baris berisi --- menjadi garis pemisah.',
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
];
