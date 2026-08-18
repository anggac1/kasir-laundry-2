import 'package:shared_preferences/shared_preferences.dart';

/// Template struk bawaan.
///
/// Teks biasa = TEKS FLAT, dicetak apa adanya.
/// Teks di dalam kurung kurawal = TEKS BERUBAH, diisi otomatis dari nota.
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
Status   : {status_pesanan}
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

/// Template untuk SATU baris item. Diulang otomatis untuk tiap item.
///
/// Memakai {qty_satuan}, bukan "{qty} {satuan}", supaya baris tanpa
/// satuan seperti hutang atau saldo tidak menyisakan spasi ganda.
const kTemplateItemBawaan = r'''{nama_item}
{qty_satuan} x {harga}[>]{subtotal}''';

/// Penyimpanan pengaturan di HP (SharedPreferences). Tidak ada server.
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

  // ------------------------------------------------------------ identitas

  String get namaToko => _p.getString('shop_name') ?? 'Lorem Ipsum Laundry';
  Future<void> setNamaToko(String v) => _p.setString('shop_name', v);

  String get alamatToko =>
      _p.getString('shop_address') ?? 'Jl. Lorem Ipsum Dolor No. 123';
  Future<void> setAlamatToko(String v) => _p.setString('shop_address', v);

  String get teleponToko => _p.getString('shop_phone') ?? '0812-0000-0000';
  Future<void> setTeleponToko(String v) => _p.setString('shop_phone', v);

  // ------------------------------------------------------------- template

  String get template => _p.getString('tpl_main') ?? kTemplateBawaan;
  Future<void> setTemplate(String v) => _p.setString('tpl_main', v);

  String get templateItem => _p.getString('tpl_item') ?? kTemplateItemBawaan;
  Future<void> setTemplateItem(String v) => _p.setString('tpl_item', v);

  Future<void> resetTemplate() async {
    await _p.remove('tpl_main');
    await _p.remove('tpl_item');
  }

  // ------------------------------------------------------ field tambahan

  /// Nama field bikinan sendiri, misalnya "Parfum" atau "Jenis Cucian".
  /// Tiap field otomatis jadi placeholder di struk: Parfum -> {parfum}
  List<String> get fieldTambahan =>
      _p.getStringList('extra_fields') ?? const <String>[];

  Future<void> setFieldTambahan(List<String> v) =>
      _p.setStringList('extra_fields', v);

  /// Ubah nama field jadi kunci placeholder.
  /// "Jenis Cucian" -> jenis_cucian
  static String kunciField(String label) {
    final bersih = label
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s_]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    return bersih.isEmpty ? 'field' : bersih;
  }

  // -------------------------------------------------------------- salinan

  /// Berapa lembar struk dicetak sekali tekan.
  int get jumlahSalinan => (_p.getInt('copies') ?? 1).clamp(1, 5);
  Future<void> setJumlahSalinan(int v) => _p.setInt('copies', v.clamp(1, 5));

  /// Judul tiap salinan, dipisah koma. Dipakai placeholder {salinan}.
  /// Salinan ke-1 memakai judul pertama, ke-2 memakai judul kedua, dst.
  String get labelSalinan =>
      _p.getString('copy_labels') ?? 'PELANGGAN,ARSIP TOKO';
  Future<void> setLabelSalinan(String v) => _p.setString('copy_labels', v);

  List<String> get daftarLabelSalinan => labelSalinan
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  /// Judul untuk salinan ke-[indeks] (mulai dari 0).
  String labelSalinanKe(int indeks) {
    final d = daftarLabelSalinan;
    if (d.isEmpty) return '';
    if (indeks < d.length) return d[indeks];
    return d.last;
  }

  // -------------------------------------------------------------- printer

  /// Lebar kertas dalam karakter. 58mm = 32, 80mm = 48.
  int get lebarKertas => _p.getInt('paper_chars') ?? 32;
  Future<void> setLebarKertas(int v) => _p.setInt('paper_chars', v);

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

  /// Font B (huruf kecil). Pada printer 58mm 384 dot seperti RPP02N,
  /// Font A muat 32 karakter dan Font B muat 42 karakter per baris.
  bool get fontKecil => _p.getBool('small_font') ?? false;
  Future<void> setFontKecil(bool v) => _p.setBool('small_font', v);

  /// Terapkan setelan yang cocok untuk RPP02N (58mm, 384 dot, tanpa pisau).
  Future<void> terapkanProfilRpp02n() async {
    await setLebarKertas(32);
    await setFontKecil(false);
    await setPotongKertas(false);
    await setBarisKosongAkhir(4);
  }

  /// Sebagian printer 58mm murah tidak punya pisau potong.
  bool get potongKertas => _p.getBool('auto_cut') ?? false;
  Future<void> setPotongKertas(bool v) => _p.setBool('auto_cut', v);

  int get barisKosongAkhir => _p.getInt('feed_lines') ?? 4;
  Future<void> setBarisKosongAkhir(int v) => _p.setInt('feed_lines', v);

  /// Estimasi selesai bawaan saat membuat nota baru (hari).
  int get estimasiHari => _p.getInt('due_days') ?? 2;
  Future<void> setEstimasiHari(int v) => _p.setInt('due_days', v);

  /// Kebiasaan nota Anda.
  ///
  /// true  = nota dibuat DI AWAL saat cucian diterima, jadi perlu
  ///         estimasi tanggal selesai.
  /// false = nota dibuat DI AKHIR saat cucian sudah bersih dan diambil,
  ///         jadi estimasi tidak ada gunanya dan tidak usah dicetak.
  ///
  /// Ini hanya nilai bawaan, tiap nota tetap bisa diatur sendiri.
  bool get pakaiEstimasi => _p.getBool('use_due_date') ?? true;
  Future<void> setPakaiEstimasi(bool v) => _p.setBool('use_due_date', v);
}
