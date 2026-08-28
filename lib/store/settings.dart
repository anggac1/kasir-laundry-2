import 'package:shared_preferences/shared_preferences.dart';

// Teks biasa = flat, dicetak apa adanya.
// Teks dalam kurung kurawal = berubah, diisi dari data nota.
const kTemplateBawaan = r'''[H][C]LOREM IPSUM
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
[B]{label_total}[>]{total}
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
  Future<void> resetPrinter() async {
    await _p.remove('paper_chars');
    await _p.remove('small_font');
    await _p.remove('auto_cut');
    await _p.remove('feed_lines');
  }
}
