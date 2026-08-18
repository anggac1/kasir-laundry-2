import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import '../utils/fmt.dart';

/// Seluruh data aplikasi disimpan di sini: SQLite lokal di HP.
/// Tidak ada server, tidak ada sinkronisasi, tidak ada login.
class DB {
  DB._();
  static final DB instance = DB._();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'laundry.db');
    return openDatabase(
      path,
      version: 4,
      onConfigure: (d) async {
        await d.execute('PRAGMA foreign_keys = ON');
      },
      // Versi 2: kolom extras untuk field tambahan buatan pengguna.
      // Versi 3: kolom cash untuk uang yang diserahkan pelanggan.
      // Versi 4: kolom print_count, jumlah cetak khusus nota itu.
      // Nota lama tetap terbaca, kolom barunya kosong.
      onUpgrade: (d, lama, baru) async {
        if (lama < 2) {
          await d.execute(
              "ALTER TABLE orders ADD COLUMN extras TEXT NOT NULL DEFAULT '{}'");
        }
        if (lama < 3) {
          await d.execute('ALTER TABLE orders ADD COLUMN cash INTEGER');
        }
        if (lama < 4) {
          await d.execute('ALTER TABLE orders ADD COLUMN print_count INTEGER');
        }
      },
      onCreate: (d, v) async {
        await d.execute('''
          CREATE TABLE services(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            unit TEXT NOT NULL,
            price INTEGER NOT NULL,
            active INTEGER NOT NULL DEFAULT 1
          )
        ''');
        await d.execute('''
          CREATE TABLE orders(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT NOT NULL UNIQUE,
            customer TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            due_at INTEGER,
            status INTEGER NOT NULL DEFAULT 0,
            paid INTEGER NOT NULL DEFAULT 0,
            paid_at INTEGER,
            cash INTEGER,
            note TEXT NOT NULL DEFAULT '',
            total INTEGER NOT NULL DEFAULT 0,
            print_count INTEGER,
            extras TEXT NOT NULL DEFAULT '{}'
          )
        ''');
        await d.execute('''
          CREATE TABLE order_items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            unit TEXT NOT NULL,
            qty REAL NOT NULL,
            price INTEGER NOT NULL,
            subtotal INTEGER NOT NULL,
            FOREIGN KEY(order_id) REFERENCES orders(id) ON DELETE CASCADE
          )
        ''');
        await d.execute(
            'CREATE INDEX idx_orders_created ON orders(created_at DESC)');
        await d.execute(
            'CREATE INDEX idx_items_order ON order_items(order_id)');

        // Contoh layanan awal. Silakan hapus atau ubah lewat menu Layanan.
        final contoh = [
          Layanan(nama: 'Cuci Kering', satuan: Satuan.kg, harga: 5000),
          Layanan(nama: 'Cuci Setrika', satuan: Satuan.kg, harga: 7000),
          Layanan(nama: 'Setrika Saja', satuan: Satuan.kg, harga: 4000),
          Layanan(nama: 'Cuci Express 1 Hari', satuan: Satuan.kg, harga: 12000),
          Layanan(nama: 'Bed Cover', satuan: Satuan.pcs, harga: 25000),
          Layanan(nama: 'Selimut', satuan: Satuan.pcs, harga: 20000),
          Layanan(nama: 'Jas / Blazer', satuan: Satuan.pcs, harga: 30000),
          Layanan(nama: 'Sepatu', satuan: Satuan.pcs, harga: 35000),
          Layanan(nama: 'Boneka Besar', satuan: Satuan.pcs, harga: 28000),
          Layanan(nama: 'Karpet', satuan: Satuan.pcs, harga: 40000),
        ];
        for (final l in contoh) {
          await d.insert('services', l.toMap());
        }
      },
    );
  }

  // ---------------------------------------------------------------- Layanan

  Future<List<Layanan>> layananSemua({bool hanyaAktif = false}) async {
    final d = await db;
    final rows = await d.query(
      'services',
      where: hanyaAktif ? 'active = 1' : null,
      orderBy: 'unit ASC, name ASC',
    );
    return rows.map(Layanan.fromMap).toList();
  }

  Future<int> layananSimpan(Layanan l) async {
    final d = await db;
    if (l.id == null) {
      return d.insert('services', l.toMap());
    }
    await d.update('services', l.toMap(), where: 'id = ?', whereArgs: [l.id]);
    return l.id!;
  }

  Future<void> layananHapus(int id) async {
    final d = await db;
    await d.delete('services', where: 'id = ?', whereArgs: [id]);
  }

  // ------------------------------------------------------------------ Nota

  /// Kode nota: LDY-YYMMDD-NNN, nomor urut harian.
  Future<String> kodeBerikutnya(DateTime now) async {
    final d = await db;
    final awal = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final akhir =
        DateTime(now.year, now.month, now.day, 23, 59, 59, 999)
            .millisecondsSinceEpoch;
    final r = await d.rawQuery(
      'SELECT COUNT(*) AS c FROM orders WHERE created_at BETWEEN ? AND ?',
      [awal, akhir],
    );
    final n = ((r.first['c'] ?? 0) as int) + 1;
    final yy = (now.year % 100).toString().padLeft(2, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    return 'LDY-$yy$mm$dd-${n.toString().padLeft(3, '0')}';
  }

  Future<int> notaSimpan(Nota n) async {
    final d = await db;
    n.total = n.hitungTotal();
    return await d.transaction<int>((txn) async {
      int id;
      if (n.id == null) {
        id = await txn.insert('orders', n.toMap());
        n.id = id;
      } else {
        id = n.id!;
        await txn.update('orders', n.toMap(), where: 'id = ?', whereArgs: [id]);
        await txn
            .delete('order_items', where: 'order_id = ?', whereArgs: [id]);
      }
      for (final it in n.items) {
        it.notaId = id;
        it.hitungUlang();
        final map = it.toMap()..remove('id');
        await txn.insert('order_items', map);
      }
      return id;
    });
  }

  Future<void> notaHapus(int id) async {
    final d = await db;
    await d.delete('orders', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> notaUbahStatus(int id, int status) async {
    final d = await db;
    await d.update('orders', {'status': status},
        where: 'id = ?', whereArgs: [id]);
  }

  /// Ubah status pembayaran satu nota saja.
  /// Dipakai saat pelanggan yang tadinya belum bayar melunasi
  /// ketika mengambil cucian. Cukup baris itu yang dibenarkan.
  Future<void> notaUbahBayar(int id, int statusBayar, {int? uang}) async {
    final d = await db;
    await d.update(
      'orders',
      {
        'paid': statusBayar,
        'paid_at': statusBayar == StatusBayar.lunas
            ? DateTime.now().millisecondsSinceEpoch
            : null,
        if (uang != null) 'cash': uang,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> notaUbahUang(int id, int? uang) async {
    final d = await db;
    await d.update('orders', {'cash': uang},
        where: 'id = ?', whereArgs: [id]);
  }

  /// [jumlah] null berarti kembali mengikuti setelan bawaan.
  Future<void> notaUbahJumlahCetak(int id, int? jumlah) async {
    final d = await db;
    await d.update('orders', {'print_count': jumlah},
        where: 'id = ?', whereArgs: [id]);
  }

  /// [status] null berarti semua status.
  /// [belumLunas] true berarti hanya yang belum dibayar.
  Future<List<Nota>> notaDaftar({
    int? status,
    bool belumLunas = false,
    String cari = '',
    int limit = 300,
  }) async {
    final d = await db;
    final where = <String>[];
    final args = <Object?>[];
    if (status != null) {
      where.add('status = ?');
      args.add(status);
    }
    if (belumLunas) where.add('paid = 0');
    if (cari.trim().isNotEmpty) {
      where.add('(customer LIKE ? OR code LIKE ?)');
      args..add('%${cari.trim()}%')..add('%${cari.trim()}%');
    }
    final rows = await d.query(
      'orders',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(Nota.fromMap).toList();
  }

  Future<Nota?> notaAmbil(int id) async {
    final d = await db;
    final rows = await d.query('orders', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final n = Nota.fromMap(rows.first);
    final its = await d.query('order_items',
        where: 'order_id = ?', whereArgs: [id], orderBy: 'id ASC');
    n.items = its.map(ItemNota.fromMap).toList();
    return n;
  }

  /// Ringkasan angka untuk kartu di beranda.
  Future<Map<String, int>> ringkasanHariIni() async {
    final d = await db;
    final now = DateTime.now();
    final awal = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final akhir = DateTime(now.year, now.month, now.day, 23, 59, 59, 999)
        .millisecondsSinceEpoch;

    final a = await d.rawQuery(
      'SELECT COUNT(*) c, COALESCE(SUM(total),0) t FROM orders WHERE created_at BETWEEN ? AND ?',
      [awal, akhir],
    );
    // Nota bersaldo (total negatif) bukan hutang, jadi tidak boleh
    // ikut mengurangi jumlah yang harus ditagih.
    final b = await d.rawQuery(
      'SELECT COUNT(*) c, '
      'COALESCE(SUM(CASE WHEN total > 0 THEN total ELSE 0 END),0) t '
      'FROM orders WHERE paid = 0',
    );
    final c = await d.rawQuery(
      'SELECT COUNT(*) c FROM orders WHERE status < ?',
      [StatusPesanan.diambil],
    );
    return {
      'notaHariIni': (a.first['c'] ?? 0) as int,
      'omzetHariIni': ((a.first['t'] ?? 0) as num).toInt(),
      'belumLunasJml': (b.first['c'] ?? 0) as int,
      'belumLunasNilai': ((b.first['t'] ?? 0) as num).toInt(),
      'belumDiambil': (c.first['c'] ?? 0) as int,
    };
  }

  /// Dipakai tombol "Hapus semua data" di Pengaturan.
  Future<void> kosongkanTransaksi() async {
    final d = await db;
    await d.delete('order_items');
    await d.delete('orders');
  }
}

/// Nota contoh untuk pratinjau di editor template.
Nota notaContoh() {
  final now = DateTime.now();
  final n = Nota(
    id: 0,
    kode: 'LDY-${(now.year % 100).toString().padLeft(2, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}-001',
    pelanggan: 'Budi Santoso',
    dibuatMs: now.millisecondsSinceEpoch,
    estimasiMs: now.add(const Duration(days: 2)).millisecondsSinceEpoch,
    status: StatusPesanan.diproses,
    statusBayar: StatusBayar.belum,
    uangDibayar: 50000,
    catatan: 'Lorem ipsum dolor sit amet.',
    items: [
      ItemNota(nama: 'Cuci Setrika', satuan: Satuan.kg, qty: 3.5, harga: 7000),
      ItemNota(nama: 'Bed Cover', satuan: Satuan.pcs, qty: 1, harga: 25000),
    ],
  );
  n.total = n.hitungTotal();
  return n;
}

/// Dipakai di beberapa layar untuk label ringkas.
String ringkasNota(Nota n) =>
    '${n.kode} - ${n.pelanggan} - ${rupiah(n.total)}';
