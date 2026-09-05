import 'dart:convert';

// Model data. Semua tersimpan lokal di SQLite pada HP, tidak ada server.

// Pembaca kolom SQLite yang tahan tipe tak terduga, supaya satu baris
// rusak tidak menggagalkan pemuatan seluruh daftar nota.
int _int(Object? v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

int? _intOpsional(Object? v) => v == null ? null : _int(v);

double _double(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

String _str(Object? v, [String fallback = '']) =>
    v == null ? fallback : v.toString();

// kg dan pcs hanya pilihan cepat. Satuan sebenarnya String bebas, boleh
// diisi apa saja atau dikosongkan untuk baris hutang dan saldo.
class Satuan {
  static const kg = 'kg';
  static const pcs = 'pcs';

  // Penanda di dropdown untuk "ketik sendiri".
  static const lainnya = '__lainnya__';

  static const semuaPlusLainnya = [kg, pcs, lainnya];

  static String label(String unit) {
    if (unit == kg) return 'Kiloan (kg)';
    if (unit == pcs) return 'Satuan (pcs)';
    if (unit == lainnya) return 'Ketik sendiri...';
    if (unit.trim().isEmpty) return 'Tanpa satuan';
    return unit;
  }

  static bool bawaan(String unit) => unit == kg || unit == pcs;

  // "3.5 kg", "1 pcs", atau "1" bila satuannya kosong.
  static String gabung(String qty, String unit) =>
      unit.trim().isEmpty ? qty : '$qty ${unit.trim()}';
}

// sembunyi dipakai bila baris pembayaran tidak perlu dicetak sama sekali,
// supaya pengguna tidak dipaksa memilih dan kertas tidak terbuang.
class StatusBayar {
  static const belum = 0;
  static const lunas = 1;
  static const sembunyi = 2;

  static const semua = [belum, lunas, sembunyi];

  static String label(int s) => switch (s) {
        lunas => 'LUNAS',
        sembunyi => 'Tidak ditampilkan',
        _ => 'BELUM BAYAR',
      };

  // Teks di struk. Kosong berarti barisnya dilewati.
  static String teksStruk(int s) => switch (s) {
        lunas => 'LUNAS',
        sembunyi => '',
        _ => 'BELUM BAYAR',
      };
}

// Satu jenis layanan, misalnya "Cuci Setrika" 7000/kg.
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
        id: _intOpsional(m['id']),
        nama: _str(m['name']),
        satuan: _str(m['unit'], Satuan.kg),
        harga: _int(m['price']),
        aktif: _int(m['active'], 1) == 1,
      );
}

// Satu baris di dalam nota.
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
        id: _intOpsional(m['id']),
        notaId: _intOpsional(m['order_id']),
        nama: _str(m['name']),
        satuan: _str(m['unit'], Satuan.kg),
        qty: _double(m['qty']),
        harga: _int(m['price']),
        subtotal: _int(m['subtotal']),
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

class Nota {
  int? id;
  String kode;
  String pelanggan;
  int dibuatMs;
  int? estimasiMs;
  int statusBayar;
  int? dibayarMs;

  // Uang yang diserahkan pelanggan. Boleh kosong, tidak wajib diisi.
  int? uangDibayar;

  String catatan;
  int total;

  // Lembar struk untuk nota ini saja. Kosong = ikut setelan bawaan.
  int? jumlahCetak;

  // Isi field tambahan buatan pengguna: {'parfum': 'Lavender'}
  Map<String, String> ekstra;

  List<ItemNota> items;

  Nota({
    this.id,
    required this.kode,
    required this.pelanggan,
    required this.dibuatMs,
    this.estimasiMs,
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

  int hitungTotal() => items.fold<int>(0, (sum, it) => sum + it.subtotal);

  // Total negatif berarti titipan pelanggan melebihi tagihan, jadi masih
  // ada sisa saldo. Struk mencetak nilai positif dengan label berbeda,
  // karena tanda minus lebih membingungkan daripada membantu.
  bool get adaSisaSaldo => total < 0;

  int get nilaiTampil => total.abs();

  String get labelTotal => adaSisaSaldo ? 'SISA SALDO' : 'TOTAL';

  int? get kembalian {
    final uang = uangDibayar;
    return uang == null ? null : uang - total;
  }

  // Uang yang diterima lebih kecil daripada tagihan.
  //
  // Ini BUKAN sisa saldo. Sisa saldo berarti pelanggan menitipkan uang
  // lebih; ini kebalikannya - pembayarannya masih kurang, dan sisanya
  // jadi hutang.
  bool get kurangBayar => (kembalian ?? 0) < 0;

  // Nilai kembalian tanpa tanda minus, sepasang dengan labelnya.
  //
  // Mengikuti cara yang sudah dipakai nilaiTampil/labelTotal: angkanya
  // selalu positif, dan yang membedakan artinya adalah label di
  // sebelahnya. Struk bertuliskan "Kembali -Rp10.000" membuat kasir
  // ragu apakah harus memberi atau menerima; "Kurang Rp10.000" tidak
  // bisa disalahartikan.
  int? get nilaiKembalian {
    final k = kembalian;
    return k == null ? null : k.abs();
  }

  String get labelKembalian => kurangBayar ? 'Kurang' : 'Kembali';

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'code': kode,
        'customer': pelanggan,
        'created_at': dibuatMs,
        'due_at': estimasiMs,
        'paid': statusBayar,
        'paid_at': dibayarMs,
        'cash': uangDibayar,
        'note': catatan,
        'total': total,
        'print_count': jumlahCetak,
        'extras': jsonEncode(ekstra),
      };

  factory Nota.fromMap(Map<String, Object?> m) => Nota(
        id: _intOpsional(m['id']),
        kode: _str(m['code']),
        pelanggan: _str(m['customer']),
        dibuatMs: _int(m['created_at']),
        estimasiMs: _intOpsional(m['due_at']),
        statusBayar: _int(m['paid']),
        dibayarMs: _intOpsional(m['paid_at']),
        uangDibayar: _intOpsional(m['cash']),
        catatan: _str(m['note']),
        total: _int(m['total']),
        jumlahCetak: _intOpsional(m['print_count']),
        ekstra: _ekstraDariJson(m['extras']),
      );
}

// Field tambahan disimpan sebagai satu kolom JSON supaya pengguna bisa
// menambah atau menghapus field tanpa mengubah struktur tabel.
Map<String, String> _ekstraDariJson(Object? v) {
  final s = v as String?;
  if (s == null || s.trim().isEmpty) return {};
  try {
    final d = jsonDecode(s);
    if (d is Map) {
      return {
        for (final e in d.entries)
          if (e.value is String || e.value is num || e.value is bool)
            e.key.toString(): e.value.toString(),
      };
    }
  } catch (_) {
    // JSON rusak. Kosongkan saja daripada menggagalkan pemuatan nota.
  }
  return {};
}
