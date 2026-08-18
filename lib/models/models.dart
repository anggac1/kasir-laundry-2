import 'dart:convert';

/// Model data aplikasi. Semua tersimpan lokal di SQLite pada HP.

/// Satuan layanan.
///
/// [kg] dan [pcs] hanya pilihan cepat. Satuan sebenarnya bertipe String
/// bebas, jadi Anda boleh mengetik apa saja: botol, paket, lembar, meter,
/// bahkan dikosongkan untuk baris seperti hutang atau saldo yang tidak
/// punya satuan sama sekali.
class Satuan {
  static const kg = 'kg';
  static const pcs = 'pcs';

  /// Penanda di dropdown untuk "ketik sendiri".
  static const lainnya = '__lainnya__';

  static const semua = [kg, pcs];
  static const semuaPlusLainnya = [kg, pcs, lainnya];

  static String label(String unit) {
    if (unit == kg) return 'Kiloan (kg)';
    if (unit == pcs) return 'Satuan (pcs)';
    if (unit == lainnya) return 'Ketik sendiri...';
    if (unit.trim().isEmpty) return 'Tanpa satuan';
    return unit;
  }

  static bool bawaan(String unit) => unit == kg || unit == pcs;

  /// "3.5 kg", "1 pcs", atau "1" kalau satuannya kosong.
  static String gabung(String qty, String unit) =>
      unit.trim().isEmpty ? qty : '$qty ${unit.trim()}';
}

/// Status pesanan laundry.
class StatusPesanan {
  static const diterima = 0;
  static const diproses = 1;
  static const selesai = 2;
  static const diambil = 3;

  static const semua = [diterima, diproses, selesai, diambil];

  static String label(int s) {
    switch (s) {
      case diterima:
        return 'Diterima';
      case diproses:
        return 'Diproses';
      case selesai:
        return 'Selesai';
      case diambil:
        return 'Diambil';
      default:
        return '-';
    }
  }
}

/// Satu jenis layanan laundry, misalnya "Cuci Setrika" 7000/kg
/// atau "Bed Cover" 25000/pcs.
class Layanan {
  int? id;
  String nama;
  String satuan;
  int harga;
  bool aktif;

  Layanan({
    this.id,
    required this.nama,
    required this.satuan,
    required this.harga,
    this.aktif = true,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': nama,
        'unit': satuan,
        'price': harga,
        'active': aktif ? 1 : 0,
      };

  factory Layanan.fromMap(Map<String, Object?> m) => Layanan(
        id: m['id'] as int?,
        nama: (m['name'] ?? '') as String,
        satuan: (m['unit'] ?? Satuan.kg) as String,
        harga: (m['price'] ?? 0) as int,
        aktif: ((m['active'] ?? 1) as int) == 1,
      );
}

/// Satu baris item di dalam nota.
class ItemNota {
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

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'order_id': notaId,
        'name': nama,
        'unit': satuan,
        'qty': qty,
        'price': harga,
        'subtotal': subtotal,
      };

  factory ItemNota.fromMap(Map<String, Object?> m) => ItemNota(
        id: m['id'] as int?,
        notaId: m['order_id'] as int?,
        nama: (m['name'] ?? '') as String,
        satuan: (m['unit'] ?? Satuan.kg) as String,
        qty: ((m['qty'] ?? 0) as num).toDouble(),
        harga: (m['price'] ?? 0) as int,
        subtotal: (m['subtotal'] ?? 0) as int,
      );

  ItemNota salin() => ItemNota(
        id: id,
        notaId: notaId,
        nama: nama,
        satuan: satuan,
        qty: qty,
        harga: harga,
        subtotal: subtotal,
      );
}

/// Status pembayaran.
///
/// [sembunyi] dipakai kalau Anda tidak ingin baris pembayaran tercetak
/// sama sekali, misalnya untuk menghemat kertas. Dengan begitu pengguna
/// tidak dipaksa memilih antara "Belum Bayar" atau "Lunas".
class StatusBayar {
  static const belum = 0;
  static const lunas = 1;
  static const sembunyi = 2;

  static const semua = [belum, lunas, sembunyi];

  static String label(int s) {
    switch (s) {
      case lunas:
        return 'LUNAS';
      case sembunyi:
        return 'Tidak ditampilkan';
      default:
        return 'BELUM BAYAR';
    }
  }

  /// Teks yang dicetak di struk. Kosong berarti barisnya dilewati.
  static String teksStruk(int s) {
    switch (s) {
      case lunas:
        return 'LUNAS';
      case sembunyi:
        return '';
      default:
        return 'BELUM BAYAR';
    }
  }
}

/// Nota / pesanan laundry.
class Nota {
  int? id;
  String kode;
  String pelanggan;

  /// Waktu dibuat, diambil dari jam perangkat (DateTime.now()).
  int dibuatMs;

  /// Estimasi selesai, boleh kosong.
  int? estimasiMs;

  int status;

  /// Lihat [StatusBayar]. Disimpan di kolom `paid`.
  int statusBayar;
  int? dibayarMs;

  /// Uang yang diserahkan pelanggan. Boleh kosong, tidak wajib diisi.
  int? uangDibayar;

  String catatan;
  int total;

  /// Berapa lembar struk dicetak untuk nota INI.
  /// Kosong berarti mengikuti setelan bawaan di Pengaturan.
  int? jumlahCetak;

  bool get lunas => statusBayar == StatusBayar.lunas;

  /// Total negatif berarti titipan pelanggan lebih besar daripada
  /// layanan yang dipakai, jadi masih ada sisa saldo. Ini terjadi kalau
  /// ada baris deposit yang nilainya melebihi tagihan.
  bool get adaSisaSaldo => total < 0;

  /// Nilai untuk ditampilkan dan dicetak: selalu positif.
  /// Yang negatif dikalikan -1, karena tanda minus di struk lebih
  /// membingungkan daripada membantu. Maknanya sudah dibawa oleh
  /// labelnya, yaitu SISA SALDO.
  int get nilaiTampil => total < 0 ? -total : total;

  /// "TOTAL" untuk tagihan biasa, "SISA SALDO" kalau pelanggan
  /// masih punya titipan.
  String get labelTotal => adaSisaSaldo ? 'SISA SALDO' : 'TOTAL';

  /// Kembalian hanya ada kalau uang benar-benar diisi.
  int? get kembalian =>
      uangDibayar == null ? null : (uangDibayar! - total);

  /// Isi field tambahan buatan pengguna, kunci -> nilai.
  /// Contoh: {'parfum': 'Lavender', 'jenis_cucian': 'Putih'}
  Map<String, String> ekstra;

  List<ItemNota> items;

  Nota({
    this.id,
    required this.kode,
    required this.pelanggan,
    required this.dibuatMs,
    this.estimasiMs,
    this.status = StatusPesanan.diterima,
    this.statusBayar = StatusBayar.belum,
    this.dibayarMs,
    this.uangDibayar,
    this.catatan = '',
    this.total = 0,
    this.jumlahCetak,
    Map<String, String>? ekstra,
    List<ItemNota>? items,
  })  : ekstra = ekstra ?? <String, String>{},
        items = items ?? [];

  DateTime get dibuat => DateTime.fromMillisecondsSinceEpoch(dibuatMs);
  DateTime? get estimasi => estimasiMs == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(estimasiMs!);

  int hitungTotal() =>
      items.fold<int>(0, (sum, it) => sum + it.subtotal);

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'code': kode,
        'customer': pelanggan,
        'created_at': dibuatMs,
        'due_at': estimasiMs,
        'status': status,
        'paid': statusBayar,
        'paid_at': dibayarMs,
        'cash': uangDibayar,
        'note': catatan,
        'total': total,
        'print_count': jumlahCetak,
        'extras': _ekstraKeJson(ekstra),
      };

  factory Nota.fromMap(Map<String, Object?> m) => Nota(
        id: m['id'] as int?,
        kode: (m['code'] ?? '') as String,
        pelanggan: (m['customer'] ?? '') as String,
        dibuatMs: (m['created_at'] ?? 0) as int,
        estimasiMs: m['due_at'] as int?,
        status: (m['status'] ?? 0) as int,
        statusBayar: (m['paid'] ?? 0) as int,
        dibayarMs: m['paid_at'] as int?,
        uangDibayar: m['cash'] as int?,
        catatan: (m['note'] ?? '') as String,
        total: (m['total'] ?? 0) as int,
        jumlahCetak: m['print_count'] as int?,
        ekstra: _ekstraDariJson(m['extras'] as String?),
      );
}

/// Field tambahan disimpan sebagai satu kolom JSON agar pengguna bisa
/// menambah atau menghapus field kapan saja tanpa mengubah struktur tabel.
String _ekstraKeJson(Map<String, String> m) {
  if (m.isEmpty) return '{}';
  return jsonEncode(m);
}

Map<String, String> _ekstraDariJson(String? s) {
  if (s == null || s.trim().isEmpty) return <String, String>{};
  try {
    final d = jsonDecode(s);
    if (d is Map) {
      return d.map((k, v) => MapEntry(k.toString(), (v ?? '').toString()));
    }
  } catch (_) {
    // Data rusak, anggap kosong daripada membuat aplikasi berhenti.
  }
  return <String, String>{};
}
