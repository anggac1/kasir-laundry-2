import 'package:shared_preferences/shared_preferences.dart';

// Teks biasa = flat, dicetak apa adanya.
// Teks dalam kurung kurawal = berubah, diisi dari data nota.
const kTemplateBawaan = r'''[C2]LOREM IPSUM
[BC]LAUNDRY & DRY CLEAN
[C]Jl. Lorem Ipsum Dolor No. 123
[C]Telp / WA: 0812-0000-0000
[BC]-- {salinan} --
---
No Nota  : {no_nota}
Tanggal  : {tanggal} {jam}
Nama     : {nama_pelanggan}
[?estimasi]Estimasi : {estimasi}
---
{daftar_item}
---
[B2]{label_total}[>]{total}
[?uang]Tunai[>]{uang}
[?kembalian]Kembali[>]{kembalian}
[?status_bayar]Bayar    : {status_bayar}
---
Catatan:
{catatan}
---
[C]Lorem ipsum dolor sit amet
[C]consectetur adipiscing elit
[C]sed do eiusmod tempor ut labore
[C]Barang tidak diambil >30 hari
[C]di luar tanggung jawab kami
[BC]TERIMA KASIH''';

// Diulang otomatis untuk tiap item. {qty_satuan} digabung agar item
// tanpa satuan (hutang, saldo) tidak menyisakan spasi ganda.
const kTemplateItemBawaan = r'''{nama_item}
{qty_satuan} x {harga}[>]{subtotal}''';

// Batas aman lebar kertas: 58mm = 32 kolom, 80mm = 48 kolom.
const kLebarMin = 16;
const kLebarMaks = 64;

// Pengaturan tersimpan di HP lewat SharedPreferences. Tidak ada server.
class Settings {
  Settings._();
  static final Settings instance = Settings._();

  late SharedPreferences _p;
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _p = await SharedPreferences.getInstance();
    _loaded = true;
  }

  String get namaToko => _p.getString('shop_name') ?? 'Lorem Ipsum Laundry';
  Future<void> setNamaToko(String v) => _p.setString('shop_name', v);

  String get alamatToko =>
      _p.getString('shop_address') ?? 'Jl. Lorem Ipsum Dolor No. 123';
  Future<void> setAlamatToko(String v) => _p.setString('shop_address', v);

  String get teleponToko => _p.getString('shop_phone') ?? '0812-0000-0000';
  Future<void> setTeleponToko(String v) => _p.setString('shop_phone', v);

  String get template => _p.getString('tpl_main') ?? kTemplateBawaan;
  Future<void> setTemplate(String v) => _p.setString('tpl_main', v);

  String get templateItem => _p.getString('tpl_item') ?? kTemplateItemBawaan;
  Future<void> setTemplateItem(String v) => _p.setString('tpl_item', v);

  Future<void> resetTemplate() async {
    await _p.remove('tpl_main');
    await _p.remove('tpl_item');
  }

  // ---- Simpanan template ------------------------------------------------
  //
  // Lima laci untuk menyimpan template yang sudah jadi, supaya bisa
  // bereksperimen tanpa takut kehilangan yang sekarang dipakai. Dibatasi
  // lima karena tiap laci menyimpan dua template utuh di SharedPreferences,
  // dan daftar yang lebih panjang justru menyulitkan memilih.
  static const int kMaksSimpanan = 5;

  // #Nama tiap laci, laci kosong bernilai string kosong
  List<String> get namaSimpanan {
    final v = _p.getStringList('tpl_slot_names') ?? const <String>[];
    return List<String>.generate(
        kMaksSimpanan, (i) => i < v.length ? v[i] : '');
  }

  // #Menyimpan template yang sedang dipakai ke laci ke-[i]
  Future<void> simpanKeLaci(int i, String nama) async {
    if (i < 0 || i >= kMaksSimpanan) return;
    final daftar = namaSimpanan;
    daftar[i] = nama.trim().isEmpty ? 'Template ${i + 1}' : nama.trim();
    await _p.setStringList('tpl_slot_names', daftar);
    await _p.setString('tpl_slot_main_$i', template);
    await _p.setString('tpl_slot_item_$i', templateItem);
  }

  // #Menimpa template yang sedang dipakai dengan isi laci ke-[i]
  Future<bool> muatDariLaci(int i) async {
    if (i < 0 || i >= kMaksSimpanan) return false;
    final utama = _p.getString('tpl_slot_main_$i');
    if (utama == null) return false;
    await setTemplate(utama);
    await setTemplateItem(
        _p.getString('tpl_slot_item_$i') ?? kTemplateItemBawaan);
    return true;
  }

  // #Mengosongkan laci ke-[i]
  Future<void> hapusLaci(int i) async {
    if (i < 0 || i >= kMaksSimpanan) return;
    final daftar = namaSimpanan;
    daftar[i] = '';
    await _p.setStringList('tpl_slot_names', daftar);
    await _p.remove('tpl_slot_main_$i');
    await _p.remove('tpl_slot_item_$i');
  }

  // #Laci ke-[i] sudah berisi atau belum
  bool laciTerisi(int i) =>
      i >= 0 && i < kMaksSimpanan && _p.getString('tpl_slot_main_$i') != null;

  // ---- Draf nota yang belum selesai ------------------------------------
  //
  // Menekan Kembali atau Home di tengah mengisi nota tidak boleh
  // menghanguskan yang sudah diketik. Isian disimpan apa adanya sebagai
  // satu teks JSON, lalu dikembalikan saat Nota Baru dibuka lagi.
  String? get draf => _p.getString('draf_nota');
  Future<void> setDraf(String v) => _p.setString('draf_nota', v);
  Future<void> hapusDraf() => _p.remove('draf_nota');

  // Field bikinan sendiri, otomatis jadi placeholder: Parfum -> {parfum}
  List<String> get fieldTambahan =>
      _p.getStringList('extra_fields') ?? const <String>[];
  Future<void> setFieldTambahan(List<String> v) =>
      _p.setStringList('extra_fields', v);

  // "Jenis Cucian" -> jenis_cucian
  static String kunciField(String label) {
    final bersih = label
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s_]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    return bersih.isEmpty ? 'field' : bersih;
  }

  int get jumlahSalinan => (_p.getInt('copies') ?? 1).clamp(1, 5);
  Future<void> setJumlahSalinan(int v) => _p.setInt('copies', v.clamp(1, 5));

  // Judul tiap salinan, dipisah koma. Mengisi placeholder {salinan}.
  String get labelSalinan =>
      _p.getString('copy_labels') ?? 'PELANGGAN,ARSIP TOKO';
  Future<void> setLabelSalinan(String v) => _p.setString('copy_labels', v);

  List<String> get daftarLabelSalinan => labelSalinan
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  String labelSalinanKe(int indeks) {
    final d = daftarLabelSalinan;
    if (d.isEmpty) return '';
    return indeks < d.length ? d[indeks] : d.last;
  }

  // Lebar kertas dalam karakter. Di-clamp karena nilai 0 atau negatif
  // membuat pembagi lebar pada baris [H] jadi nol.
  int get lebarKertas => (_p.getInt('paper_chars') ?? 32).clamp(kLebarMin, kLebarMaks);
  Future<void> setLebarKertas(int v) =>
      _p.setInt('paper_chars', v.clamp(kLebarMin, kLebarMaks));

  String? get printerMac => _p.getString('printer_mac');
  String? get printerNama => _p.getString('printer_name');

  Future<void> setPrinter(String mac, String nama) async {
    await _p.setString('printer_mac', mac);
    await _p.setString('printer_name', nama);
  }

  Future<void> lupakanPrinter() async {
    await _p.remove('printer_mac');
    await _p.remove('printer_name');
  }

  // Font B muat 42 kolom di printer 58mm, Font A muat 32.
  bool get fontKecil => _p.getBool('small_font') ?? false;
  Future<void> setFontKecil(bool v) => _p.setBool('small_font', v);

  // #Keterangan lebar kertas dalam mm, ikut memperhitungkan Font B
  //
  // Jumlah kolom saja tidak cukup untuk menebak lebar fisiknya: 42 kolom
  // bisa berarti kertas 58mm dengan Font B, atau kertas 80mm dengan Font A.
  String get keteranganKertas {
    final k = lebarKertas;
    final f = fontKecil ? 'Font B' : 'Font A';
    final mm = fontKecil
        ? (k <= 42 ? '58mm' : '80mm')
        : (k <= 32 ? '58mm' : '80mm');
    return '$mm, $f';
  }

  // Daftar perangkat Bluetooth yang terakhir terlihat, disimpan sebagai
  // "mac|nama" per baris.
  //
  // Gunanya supaya layar Printer bisa langsung menampilkan daftarnya saat
  // dibuka, tanpa menunggu Android menjawab. Daftar sebenarnya menyusul
  // beberapa ratus milidetik kemudian dan menimpa yang ini.
  List<String> get printerTerakhir =>
      _p.getStringList('printer_cache') ?? const <String>[];
  Future<void> setPrinterTerakhir(List<String> v) =>
      _p.setStringList('printer_cache', v.take(30).toList());

  // Lebar gambar nota yang dibagikan, dalam piksel.
  //
  // Ini UKURAN gambarnya, bukan ketajaman: 800 berarti gambarnya
  // benar-benar selebar 800 piksel. Struknya digambar ulang seukuran
  // itu, jadi tulisannya tetap halus di ukuran berapa pun.
  int get lebarGambar =>
      (_p.getInt('share_image_width') ?? 800).clamp(400, 2000);
  Future<void> setLebarGambar(int v) =>
      _p.setInt('share_image_width', v.clamp(400, 2000));

  // Pola nama berkas nota yang dibagikan ke pelanggan.
  //
  // Bawaannya tanpa nomor nota: kode internal seperti LDY-260830-001
  // tidak ada gunanya bagi pelanggan dan terlihat tidak rapi.
  String get polaNamaBerkas =>
      _p.getString('share_filename') ?? 'Nota {nama} {tanggal}';
  Future<void> setPolaNamaBerkas(String v) =>
      _p.setString('share_filename', v.trim().isEmpty ? 'Nota' : v.trim());

  // Ketajaman cetak, 0 sampai 3. 0 berarti bawaan printer, tanpa
  // perintah tambahan sama sekali.
  //
  // Di atas 0, tiap titik dipanaskan dua kali (ESC G) dan lama
  // pemanasannya dinaikkan. Ini penawar kertas thermal murah yang
  // hasilnya pudar.
  int get ketajamanCetak => (_p.getInt('print_darkness') ?? 0).clamp(0, 3);
  Future<void> setKetajamanCetak(int v) =>
      _p.setInt('print_darkness', v.clamp(0, 3));

  // Kelambatan cetak, 0 sampai 2. Memperbesar jeda antar baris titik.
  // Mencetak lebih lama, tapi kertas punya waktu lebih untuk menghitam.
  int get kelambatanCetak => (_p.getInt('print_slowness') ?? 0).clamp(0, 2);
  Future<void> setKelambatanCetak(int v) =>
      _p.setInt('print_slowness', v.clamp(0, 2));

  // Banyak printer 58mm murah, termasuk RPP02N, tidak punya pisau potong.
  bool get potongKertas => _p.getBool('auto_cut') ?? false;
  Future<void> setPotongKertas(bool v) => _p.setBool('auto_cut', v);

  int get barisKosongAkhir => (_p.getInt('feed_lines') ?? 4).clamp(0, 12);
  Future<void> setBarisKosongAkhir(int v) =>
      _p.setInt('feed_lines', v.clamp(0, 12));

  int get estimasiHari => (_p.getInt('due_days') ?? 2).clamp(0, 365);
  Future<void> setEstimasiHari(int v) => _p.setInt('due_days', v.clamp(0, 365));

  // true  = nota dicetak di awal saat cucian diterima, perlu estimasi.
  // false = nota dicetak di akhir saat diambil, estimasi tidak dipakai.
  bool get pakaiEstimasi => _p.getBool('use_due_date') ?? true;
  Future<void> setPakaiEstimasi(bool v) => _p.setBool('use_due_date', v);

  // Nama yang dibuang pengguna dari daftar saran, biasanya karena salah
  // ketik. Notanya sendiri tidak dihapus, hanya tidak disarankan lagi.
  List<String> get namaDisembunyikan =>
      _p.getStringList('hidden_names') ?? const <String>[];

  Future<void> sembunyikanNama(String nama) async {
    final v = nama.trim();
    if (v.isEmpty) return;
    final daftar = [...namaDisembunyikan];
    if (daftar.any((n) => n.toLowerCase() == v.toLowerCase())) return;
    daftar.add(v);
    await _p.setStringList('hidden_names', daftar);
  }

  Future<void> tampilkanSemuaNama() => _p.remove('hidden_names');

  // Kartu hutang di beranda: hitung ulang sendiri, atau tunggu ditekan.
  //
  // Menghitungnya berarti membaca setiap nota yang belum lunas, jadi makin
  // lama makin berat. Selama notanya masih sedikit itu tidak terasa, maka
  // bawaannya otomatis. Kalau sudah menumpuk, matikan lewat Pengaturan dan
  // perbarui sendiri lewat tombol di beranda saat memang perlu.
  bool get hutangOtomatis => _p.getBool('debt_auto') ?? true;
  Future<void> setHutangOtomatis(bool v) => _p.setBool('debt_auto', v);

  // Kembalikan seluruh setelan printer ke bawaan, yang memang sudah
  // cocok untuk RPP02N: 58mm, tanpa pisau, Font A.
  // Kata pengantar yang menemani berkas saat dikirim ke pelanggan.
  //
  // Yang dikirim BUKAN isi struknya - struknya sudah ada di gambar atau
  // PDF yang dilampirkan. Ini kalimat sapaan yang muncul di atas
  // lampiran, seperti orang mengirim pesan biasa.
  String get pesanPengantar =>
      _p.getString('share_message') ??
      'Terima kasih sudah laundry di {toko}. Berikut struknya.';
  Future<void> setPesanPengantar(String v) =>
      _p.setString('share_message', v.trim());

  Future<void> resetPrinter() async {
    await _p.remove('paper_chars');
    await _p.remove('small_font');
    await _p.remove('auto_cut');
    await _p.remove('feed_lines');
    await _p.remove('print_darkness');
    await _p.remove('print_slowness');
  }

  // #Mengembalikan SEMUA setelan ke bawaan
  //
  // Laci template sengaja TIDAK ikut dihapus. Isinya template yang
  // disusun sendiri oleh pengguna dan bisa jadi hasil kerja berjam-jam;
  // menghapusnya diam-diam lewat tombol yang tertulis "setelan" adalah
  // kejutan yang tidak bisa dibatalkan. Laci punya tombol kosongkannya
  // sendiri di layar Template.
  Future<void> resetSemuaSetelan() async {
    const kunci = [
      // Identitas
      'shop_name', 'shop_address', 'shop_phone',
      // Kertas dan huruf
      'paper_chars', 'small_font', 'auto_cut', 'feed_lines',
      'print_darkness', 'print_slowness',
      // Template yang sedang dipakai
      'tpl_main', 'tpl_item',
      // Berbagi
      'share_filename', 'share_image_width', 'share_message',
      // Nota
      'copies', 'copy_labels', 'use_due_date', 'debt_auto',
      'extra_fields', 'due_days',
      // Draf yang belum selesai
      'draf_nota',
    ];
    for (final k in kunci) {
      await _p.remove(k);
    }
  }
}
