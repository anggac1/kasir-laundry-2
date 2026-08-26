// Salinan kode logika inti sebagai teks, supaya bisa dibaca langsung dari
// HP saat mencari bug. Ini SALINAN, bukan kode yang dijalankan: kalau file
// aslinya berubah, teks di sini harus ikut diperbarui.
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
  int? id;
  int? notaId;
  String nama;
  String satuan;
  double qty;
  int harga;
  int subtotal;

  ItemNota({
    this.id,
    this.notaId,
    required this.nama,
    required this.satuan,
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
      kode:
          '''int hitungTotal() => items.fold<int>(0, (sum, it) => sum + it.subtotal);''',
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
  n.total = n.hitungTotal();
  return d.transaction<int>((txn) async {
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
          'Nomor urut diambil dari kode TERBESAR yang sudah terpakai hari '
          'itu, bukan dari banyaknya nota. Dengan begitu kode tetap unik '
          'walau ada nota yang dihapus atau jam HP diubah mundur.',
      kode: '''Future<String> kodeBerikutnya(DateTime now) async {
  final d = await db;
  final yy = (now.year % 100).toString().padLeft(2, '0');
  final mm = now.month.toString().padLeft(2, '0');
  final dd = now.day.toString().padLeft(2, '0');
  final awalan = 'LDY-\$yy\$mm\$dd-';

  final rows = await d.rawQuery(
    'SELECT code FROM orders WHERE code LIKE ? ORDER BY code DESC LIMIT 1',
    ['\$awalan%'],
  );

  var urut = 1;
  if (rows.isNotEmpty) {
    final terakhir = rows.first['code']?.toString() ?? '';
    final n = int.tryParse(terakhir.split('-').last);
    if (n != null) urut = n + 1;
  }
  return '\$awalan\${urut.toString().padLeft(3, '0')}';
}''',
    ),
    PotonganKode(
      judul: 'Ringkasan beranda',
      berkas: 'lib/db/db.dart',
      catatan:
          'Beranda hanya menampilkan tagihan belum lunas dan cucian yang '
          'belum diambil. Nota bersaldo (total negatif) sengaja tidak ikut '
          'mengurangi nilai tagihan, karena itu titipan pelanggan, bukan '
          'hutang yang batal.',
      kode: '''-- Nota yang belum dibayar, saldo negatif tidak mengurangi
SELECT COUNT(*) c,
       COALESCE(SUM(CASE WHEN total > 0 THEN total ELSE 0 END),0) t
FROM orders
WHERE paid = :belum;

-- Cucian yang belum diambil (status < diambil)
SELECT COUNT(*) c FROM orders WHERE status < :diambil;''',
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
          'kuncinya tidak ada di peta ini, biasanya karena salah ketik. '
          'Teks diubah ke ASCII lebih dulu karena lebar cetak dihitung dari '
          'hasil konversi itu.',
      kode: '''static String _isi(String teks, Map<String, String> vars) {
  var out = teks;
  vars.forEach((k, v) => out = out.replaceAll(k, v));
  return out;
}

final efektif = lebarEfektif(lebar, p.besar);
final teks = EscPos.keAscii(_isi(p.teks, vars));

// Tag [>] mendorong sisa teks ke kanan
final pisah = teks.indexOf('[>]');
if (pisah >= 0) {
  final kiri  = teks.substring(0, pisah);
  final kanan = teks.substring(pisah + 3);
  final sisa  = efektif - kiri.length - kanan.length;

  if (sisa >= 1) {
    return [
      BarisStruk(kiri + ' ' * sisa + kanan, tebal: p.tebal, besar: p.besar)
    ];
  }
  // Tidak muat sebaris: kiri di atas, kanan rata kanan di bawahnya.
}''',
    ),
    PotonganKode(
      judul: 'Penyusunan salinan struk',
      berkas: 'lib/print/printer_service.dart',
      catatan:
          'Tiap salinan dirender ulang dari awal supaya placeholder {salinan} '
          'bisa berbeda. Byte-nya digabung jadi satu kiriman, jadi printer '
          'hanya disambungi sekali. Banyaknya salinan memakai urutan: '
          'paksaan langsung, lalu setelan nota ini, baru setelan bawaan.',
      kode: '''// Urutan: paksaan langsung, lalu setelan nota ini, baru bawaan.
int jumlahSalinan(Nota nota, [int? paksa]) =>
    paksa ?? nota.jumlahCetak ?? Settings.instance.jumlahSalinan;

List<int> susunBytes(Nota nota, {int? paksaSalinan}) {
  final s = Settings.instance;
  final cfg = StrukConfig.dari(s);
  final jumlah = jumlahSalinan(nota, paksaSalinan);

  final semua = <int>[];
  for (var i = 0; i < jumlah; i++) {
    final baris = Struk.render(nota, cfg,
        salinan: s.labelSalinanKe(i), salinanKe: i + 1);
    semua.addAll(EscPos.dariBaris(
      baris,
      barisKosongAkhir: s.barisKosongAkhir,
      potongKertas: s.potongKertas,
      fontKecil: s.fontKecil,
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
ESC M n      1B 4D n      font: 0 Font A (32 kolom), 1 Font B (42 kolom)
ESC a n      1B 61 n      rata: 0 kiri, 1 tengah, 2 kanan
ESC E n      1B 45 n      tebal: 1 nyala, 0 mati
GS  ! n      1D 21 n      ukuran: 00 normal, 11 dobel
ESC ! n      1B 21 n      ukuran cadangan untuk printer lama
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
