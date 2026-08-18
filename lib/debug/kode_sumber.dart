/// Salinan kode logika inti, ditanam sebagai teks supaya bisa dibaca
/// langsung dari HP saat mencari bug tanpa membuka laptop.
///
/// PENTING: ini SALINAN, bukan kode yang benar-benar dijalankan.
/// Kalau Anda mengubah logika di file aslinya, perbarui juga teks di sini
/// agar tidak menyesatkan saat debug.
class KodeSumber {
  static const daftar = <PotonganKode>[
    PotonganKode(
      judul: 'Subtotal per item',
      berkas: 'lib/models/models.dart',
      catatan:
          'Dipanggil setiap kali item disimpan. Hasil pembulatan memakai '
          'round(), jadi 0,5 dibulatkan ke atas. qty bertipe double supaya '
          'berat kiloan bisa desimal, harga bertipe int rupiah penuh.',
      kode: '''class ItemNota {
  double qty;      // 3.5 untuk 3,5 kg
  int    harga;    // 7000 (rupiah per satuan)
  int    subtotal;

  ItemNota({
    required this.qty,
    required this.harga,
    int? subtotal,
  }) : subtotal = subtotal ?? (qty * harga).round();

  void hitungUlang() => subtotal = (qty * harga).round();
}''',
    ),
    PotonganKode(
      judul: 'Total nota',
      berkas: 'lib/models/models.dart',
      catatan:
          'Menjumlahkan subtotal seluruh item. Tidak ada pajak dan tidak ada '
          'diskon. Kalau total di layar tidak cocok, periksa dulu subtotal '
          'tiap item lewat tab Uji Hitung.',
      kode: '''int hitungTotal() =>
    items.fold<int>(0, (sum, it) => sum + it.subtotal);''',
    ),
    PotonganKode(
      judul: 'Penyimpanan nota',
      berkas: 'lib/db/db.dart',
      catatan:
          'Total selalu dihitung ulang sebelum disimpan, jadi nilai di '
          'database tidak mungkin berbeda dari jumlah itemnya. Item lama '
          'dihapus lalu ditulis ulang supaya tidak ada sisa baris yatim.',
      kode: '''Future<int> notaSimpan(Nota n) async {
  final d = await db;
  n.total = n.hitungTotal();          // hitung ulang, jangan percaya nilai lama
  return await d.transaction<int>((txn) async {
    int id;
    if (n.id == null) {
      id = await txn.insert('orders', n.toMap());
      n.id = id;
    } else {
      id = n.id!;
      await txn.update('orders', n.toMap(), where: 'id = ?', whereArgs: [id]);
      await txn.delete('order_items', where: 'order_id = ?', whereArgs: [id]);
    }
    for (final it in n.items) {
      it.notaId = id;
      it.hitungUlang();
      await txn.insert('order_items', it.toMap()..remove('id'));
    }
    return id;
  });
}''',
    ),
    PotonganKode(
      judul: 'Nomor nota harian',
      berkas: 'lib/db/db.dart',
      catatan:
          'Nomor urut dihitung dari BANYAKNYA nota hari itu, bukan dari nomor '
          'terakhir. Jadi kalau ada nota yang dihapus, nomor berikutnya bisa '
          'terpakai ulang. Ini titik yang perlu diubah kalau Anda butuh nomor '
          'yang benar-benar tidak pernah kembar.',
      kode: '''Future<String> kodeBerikutnya(DateTime now) async {
  final awal  = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
  final akhir = DateTime(now.year, now.month, now.day, 23, 59, 59, 999)
                  .millisecondsSinceEpoch;
  final r = await d.rawQuery(
    'SELECT COUNT(*) AS c FROM orders WHERE created_at BETWEEN ? AND ?',
    [awal, akhir],
  );
  final n = (r.first['c'] as int) + 1;
  // LDY-260817-001
  return 'LDY-\$yy\$mm\$dd-\${n.toString().padLeft(3, '0')}';
}''',
    ),
    PotonganKode(
      judul: 'Ringkasan beranda',
      berkas: 'lib/db/db.dart',
      catatan:
          'Omzet hari ini menjumlahkan SEMUA nota hari itu, termasuk yang '
          'belum dibayar. Kalau Anda ingin omzet hanya menghitung yang lunas, '
          'tambahkan AND paid = 1 pada query pertama.',
      kode: '''-- Omzet dan jumlah nota hari ini
SELECT COUNT(*) c, COALESCE(SUM(total),0) t
FROM orders
WHERE created_at BETWEEN :awal AND :akhir;

-- Nota yang belum dibayar
SELECT COUNT(*) c, COALESCE(SUM(total),0) t
FROM orders
WHERE paid = 0;

-- Cucian yang belum diambil (status < 3)
SELECT COUNT(*) c FROM orders WHERE status < 3;''',
    ),
    PotonganKode(
      judul: 'Format rupiah',
      berkas: 'lib/utils/fmt.dart',
      catatan:
          'Ditulis manual tanpa paket intl. Selalu membulatkan ke rupiah '
          'penuh. Pemisah ribuan memakai titik.',
      kode: '''String rupiah(num value) {
  final n = value.round();
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '\${n < 0 ? '-' : ''}Rp\$buf';
}''',
    ),
    PotonganKode(
      judul: 'Pengisian template struk',
      berkas: 'lib/print/receipt.dart',
      catatan:
          'Placeholder diganti dengan replaceAll biasa, satu per satu. '
          'Kalau ada placeholder yang tidak berubah saat dicetak, berarti '
          'kuncinya tidak ada di peta ini, biasanya karena salah ketik.',
      kode: '''static String _isi(String teks, Map<String, String> vars) {
  var out = teks;
  vars.forEach((k, v) => out = out.replaceAll(k, v));
  return out;
}

// Tag [>] mendorong sisa teks ke kanan
if (teks.contains('[>]')) {
  final idx   = teks.indexOf('[>]');
  final kiri  = teks.substring(0, idx);
  final kanan = teks.substring(idx + 3);
  final sisa  = efektif - kiri.length - kanan.length;
  if (sisa >= 1) return kiri + ' ' * sisa + kanan;
  // tidak muat: kanan dipindah ke baris bawah, rata kanan
}''',
    ),
    PotonganKode(
      judul: 'Penyusunan salinan struk',
      berkas: 'lib/print/printer_service.dart',
      catatan:
          'Tiap salinan dirender ulang dari awal supaya placeholder {salinan} '
          'bisa berbeda. Byte-nya digabung jadi satu kiriman, jadi printer '
          'hanya disambungi sekali.',
      kode: '''List<int> susunBytes(Nota nota, {int? paksaSalinan}) {
  final s = Settings.instance;
  final cfg = StrukConfig.dari(s);
  final jumlah = paksaSalinan ?? s.jumlahSalinan;

  final semua = <int>[];
  for (var i = 0; i < jumlah; i++) {
    final baris = Struk.render(
      nota, cfg,
      salinan: s.labelSalinanKe(i),   // PELANGGAN, ARSIP TOKO, ...
      salinanKe: i + 1,
    );
    semua.addAll(EscPos.dariBaris(
      baris,
      barisKosongAkhir: s.barisKosongAkhir,
      potongKertas: s.potongKertas,
    ));
  }
  return semua;
}''',
    ),
    PotonganKode(
      judul: 'Perintah ESC/POS',
      berkas: 'lib/print/escpos.dart',
      catatan:
          'Byte mentah yang dikirim ke printer. Kalau hasil cetak berantakan, '
          'biasanya masalahnya di sini atau di code page. Huruf di luar ASCII '
          'diganti tanda tanya.',
      kode: '''ESC @        1B 40        reset printer
ESC t 0      1B 74 00     code page PC437
ESC R 0      1B 52 00     charset USA
ESC a n      1B 61 n      rata: 0 kiri, 1 tengah, 2 kanan
ESC E n      1B 45 n      tebal: 1 nyala, 0 mati
GS  ! n      1D 21 n      ukuran: 00 normal, 11 dobel
GS  V 0      1D 56 00     potong kertas
LF           0A           baris baru''',
    ),
  ];
}

class PotonganKode {
  final String judul;
  final String berkas;
  final String catatan;
  final String kode;

  const PotonganKode({
    required this.judul,
    required this.berkas,
    required this.catatan,
    required this.kode,
  });
}
