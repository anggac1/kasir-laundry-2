import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';

// Seluruh data ada di SQLite lokal pada HP. Tidak ada server maupun login.
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
      onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
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

        for (final l in _layananContoh()) {
          await d.insert('services', l.toMap());
        }
      },
    );
  }

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
    if (l.id == null) return d.insert('services', l.toMap());
    await d.update('services', l.toMap(), where: 'id = ?', whereArgs: [l.id]);
    return l.id!;
  }

  Future<void> layananHapus(int id) async {
    final d = await db;
    await d.delete('services', where: 'id = ?', whereArgs: [id]);
  }

  // Nomor urut harian: LDY-YYMMDD-NNN.
  //
  // Memakai MAX nomor yang sudah terpakai, bukan COUNT, supaya kode tetap
  // unik walau ada nota yang dihapus atau jam HP diubah mundur. COUNT akan
  // memberi nomor yang sama dua kali dan melanggar UNIQUE pada kolom code.
  Future<String> kodeBerikutnya(DateTime now) async {
    final d = await db;
    final yy = (now.year % 100).toString().padLeft(2, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final awalan = 'LDY-$yy$mm$dd-';

    final rows = await d.rawQuery(
      'SELECT code FROM orders WHERE code LIKE ? ORDER BY code DESC LIMIT 1',
      ['$awalan%'],
    );

    var urut = 1;
    if (rows.isNotEmpty) {
      final terakhir = rows.first['code']?.toString() ?? '';
      final n = int.tryParse(terakhir.split('-').last);
      if (n != null) urut = n + 1;
    }
    return '$awalan${urut.toString().padLeft(3, '0')}';
  }

  Future<int> notaSimpan(Nota n) async {
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
  }

  Future<void> notaHapus(int id) async {
    final d = await db;
    // Dihapus manual, tidak menggantungkan diri pada ON DELETE CASCADE
    // yang baru aktif kalau PRAGMA foreign_keys berhasil dipasang.
    await d.transaction((txn) async {
      await txn.delete('order_items', where: 'order_id = ?', whereArgs: [id]);
      await txn.delete('orders', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> notaUbahStatus(int id, int status) async {
    final d = await db;
    await d.update('orders', {'status': status},
        where: 'id = ?', whereArgs: [id]);
  }

  // Dipakai saat pelanggan yang tadinya belum bayar melunasi ketika
  // mengambil cucian: cukup baris itu yang dibenarkan.
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
    await d.update('orders', {'cash': uang}, where: 'id = ?', whereArgs: [id]);
  }

  // null berarti kembali mengikuti setelan bawaan.
  Future<void> notaUbahJumlahCetak(int id, int? jumlah) async {
    final d = await db;
    await d.update('orders', {'print_count': jumlah},
        where: 'id = ?', whereArgs: [id]);
  }

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

    final kata = cari.trim();
    if (kata.isNotEmpty) {
      where.add('(customer LIKE ? OR code LIKE ?)');
      args..add('%$kata%')..add('%$kata%');
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

  // Ambil beberapa nota lengkap dengan itemnya sekaligus. Dipakai layar
  // ekspor, menggantikan satu query per nota yang membekukan layar.
  Future<List<Nota>> notaLengkap(List<int> ids) async {
    if (ids.isEmpty) return [];
    final d = await db;
    final tanya = List.filled(ids.length, '?').join(',');

    final rows = await d.query('orders',
        where: 'id IN ($tanya)', whereArgs: ids, orderBy: 'created_at DESC');
    final notas = rows.map(Nota.fromMap).toList();

    final its = await d.query('order_items',
        where: 'order_id IN ($tanya)', whereArgs: ids, orderBy: 'id ASC');

    final perNota = <int, List<ItemNota>>{};
    for (final r in its) {
      final it = ItemNota.fromMap(r);
      final nid = it.notaId;
      if (nid != null) (perNota[nid] ??= []).add(it);
    }
    for (final n in notas) {
      n.items = perNota[n.id] ?? [];
    }
    return notas;
  }

  // Angka untuk kartu di beranda.
  Future<Map<String, int>> ringkasanHariIni() async {
    final d = await db;

    // Nota bersaldo (total negatif) bukan hutang, jadi tidak boleh ikut
    // mengurangi jumlah yang harus ditagih.
    final hutang = await d.rawQuery(
      'SELECT COUNT(*) c, '
      'COALESCE(SUM(CASE WHEN total > 0 THEN total ELSE 0 END),0) t '
      'FROM orders WHERE paid = ?',
      [StatusBayar.belum],
    );
    final proses = await d.rawQuery(
      'SELECT COUNT(*) c FROM orders WHERE status < ?',
      [StatusPesanan.diambil],
    );

    int ambil(List<Map<String, Object?>> r, String k) {
      if (r.isEmpty) return 0;
      final v = r.first[k];
      return v is num ? v.toInt() : 0;
    }

    return {
      'belumLunasJml': ambil(hutang, 'c'),
      'belumLunasNilai': ambil(hutang, 't'),
      'belumDiambil': ambil(proses, 'c'),
    };
  }

  Future<void> kosongkanTransaksi() async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.delete('order_items');
      await txn.delete('orders');
    });
  }
}

// Isi awal menu Layanan. Boleh dihapus atau diubah lewat aplikasi.
List<Layanan> _layananContoh() => [
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

// Nota isian untuk pratinjau di editor template dan layar debug.
Nota notaContoh() {
  final now = DateTime.now();
  final yy = (now.year % 100).toString().padLeft(2, '0');
  final mm = now.month.toString().padLeft(2, '0');
  final dd = now.day.toString().padLeft(2, '0');

  final n = Nota(
    id: 0,
    kode: 'LDY-$yy$mm$dd-001',
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
