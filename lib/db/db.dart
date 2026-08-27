import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import '../store/settings.dart';

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
      version: 7,
      onConfigure: (d) async {
        await d.execute('PRAGMA foreign_keys = ON');
        // WAL: tulis jauh lebih cepat dan baca tidak terhalang tulis.
        await d.execute('PRAGMA journal_mode = WAL');
        // NORMAL, bukan FULL: cukup aman dengan WAL dan jauh lebih ringan
        // untuk kartu memori HP murah yang lambat menulis.
        await d.execute('PRAGMA synchronous = NORMAL');
      },
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
        if (lama < 5) {
          // Kolom status pesanan dibuang. SQLite lama tidak punya DROP
          // COLUMN, jadi tabelnya disusun ulang.
          //
          // Foreign key WAJIB dimatikan selama proses ini. Android memakai
          // legacy_alter_table, sehingga RENAME ikut mengubah acuan foreign
          // key di order_items menjadi orders_lama. Tanpa dimatikan, DROP
          // TABLE orders_lama memicu ON DELETE CASCADE dan MENGHAPUS SELURUH
          // ITEM NOTA. Salinan tabel seperti ini memang jalur resmi yang
          // dianjurkan SQLite untuk membuang kolom.
          await d.execute('PRAGMA foreign_keys = OFF');
          try {
            await d.execute('ALTER TABLE orders RENAME TO orders_lama');
            await _buatTabelNota(d);
            await d.execute('''
              INSERT INTO orders(id, code, customer, created_at, due_at, paid,
                                 paid_at, cash, note, total, print_count, extras)
              SELECT id, code, customer, created_at, due_at, paid,
                     paid_at, cash, note, total, print_count, extras
              FROM orders_lama
            ''');
            await d.execute('DROP TABLE orders_lama');

            // order_items disusun ulang juga, supaya acuan foreign key-nya
            // kembali menunjuk ke orders, bukan orders_lama yang sudah tiada.
            await d.execute('ALTER TABLE order_items RENAME TO items_lama');
            await _buatTabelItem(d);
            await d.execute('''
              INSERT INTO order_items(id, order_id, name, unit, qty, price, subtotal)
              SELECT id, order_id, name, unit, qty, price, subtotal
              FROM items_lama
            ''');
            await d.execute('DROP TABLE items_lama');
          } finally {
            await d.execute('PRAGMA foreign_keys = ON');
          }
          await _buatIndeks(d);
        }
        if (lama < 6) {
          // Indeks belum-lunas disusun ulang agar mencakup kolom total,
          // supaya kartu hutang di beranda tidak perlu membuka tabel.
          await _buatIndeks(d);
        }
        if (lama < 7) {
          // Perbaikan database yang rusak oleh migrasi v5 versi awal.
          //
          // Migrasi itu menyusun ulang tabel orders tanpa mematikan foreign
          // key lebih dulu. Di Android, RENAME ikut mengubah acuan foreign
          // key di order_items menjadi orders_lama. Akibatnya setiap upaya
          // menyimpan item nota gagal dengan "no such table: orders_lama",
          // dan layar yang menunggunya berputar tanpa henti.
          await _perbaikiAcuanItem(d);
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
        await _buatTabelNota(d);
        await _buatTabelItem(d);
        await _buatIndeks(d);

        for (final l in _layananContoh()) {
          await d.insert('services', l.toMap());
        }
      },
    );
  }

  static Future<void> _buatTabelNota(Database d) => d.execute('''
        CREATE TABLE orders(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          code TEXT NOT NULL UNIQUE,
          customer TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          due_at INTEGER,
          paid INTEGER NOT NULL DEFAULT 0,
          paid_at INTEGER,
          cash INTEGER,
          note TEXT NOT NULL DEFAULT '',
          total INTEGER NOT NULL DEFAULT 0,
          print_count INTEGER,
          extras TEXT NOT NULL DEFAULT '{}'
        )
      ''');

  // Susun ulang order_items bila acuan foreign key-nya salah menunjuk ke
  // tabel yang sudah tidak ada. Aman dijalankan pada database yang sehat:
  // kalau acuannya sudah benar, tidak ada yang dikerjakan.
  static Future<void> _perbaikiAcuanItem(Database d) async {
    final baris = await d.rawQuery(
      "SELECT sql FROM sqlite_master WHERE type='table' AND name='order_items'",
    );
    if (baris.isEmpty) return;

    final skema = baris.first['sql']?.toString() ?? '';
    if (!skema.contains('orders_lama')) return;

    await d.execute('PRAGMA foreign_keys = OFF');
    try {
      await d.execute('ALTER TABLE order_items RENAME TO items_rusak');
      await _buatTabelItem(d);
      // Baris yatim ikut dibuang: notanya memang sudah tidak ada.
      await d.execute('''
        INSERT INTO order_items(id, order_id, name, unit, qty, price, subtotal)
        SELECT i.id, i.order_id, i.name, i.unit, i.qty, i.price, i.subtotal
        FROM items_rusak i
        WHERE EXISTS (SELECT 1 FROM orders o WHERE o.id = i.order_id)
      ''');
      await d.execute('DROP TABLE items_rusak');
    } finally {
      await d.execute('PRAGMA foreign_keys = ON');
    }
    await d.execute(
        'CREATE INDEX IF NOT EXISTS idx_items_order ON order_items(order_id)');
  }

  static Future<void> _buatTabelItem(Database d) => d.execute('''
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

  // Indeks yang benar-benar terpakai, tidak lebih. Tiap indeks tambahan
  // memperlambat penyimpanan nota dan membesarkan berkas database.
  //
  // Dibuang dulu sebelum dibuat: IF NOT EXISTS hanya melihat namanya, jadi
  // tanpa ini database lama akan tetap memakai bentuk indeks yang usang.
  static Future<void> _buatIndeks(Database d) async {
    await d.execute('DROP INDEX IF EXISTS idx_orders_paid');

    // Daftar nota di beranda, urut terbaru.
    await d.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_created ON orders(created_at DESC)');
    // Saringan "belum lunas" sekaligus kartu hutang di beranda.
    //
    // Kolom total ikut dimasukkan meski tidak disaring maupun diurut:
    // dengan begitu penjumlahan hutang selesai di dalam indeks saja, tanpa
    // membuka tabel baris demi baris. Pada 200.000 nota, itu memangkas
    // waktunya dari ~18 ms jadi ~3 ms.
    await d.execute('CREATE INDEX IF NOT EXISTS idx_orders_paid '
        'ON orders(paid, created_at DESC, total)');
    await d.execute(
        'CREATE INDEX IF NOT EXISTS idx_items_order ON order_items(order_id)');
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

    // Perbandingan rentang, bukan LIKE: hanya bentuk ini yang bisa memakai
    // indeks UNIQUE pada kolom code. Dengan LIKE, SQLite menyisir seluruh
    // tabel, dan pada puluhan ribu nota itu terasa jelas di HP lambat.
    final rows = await d.rawQuery(
      'SELECT code FROM orders WHERE code >= ? AND code < ? '
      'ORDER BY code DESC LIMIT 1',
      [awalan, '$awalan\u{10FFFF}'],
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
    _ringkasanUsang();
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
    _ringkasanUsang();
    // Dihapus manual, tidak menggantungkan diri pada ON DELETE CASCADE
    // yang baru aktif kalau PRAGMA foreign_keys berhasil dipasang.
    await d.transaction((txn) async {
      await txn.delete('order_items', where: 'order_id = ?', whereArgs: [id]);
      await txn.delete('orders', where: 'id = ?', whereArgs: [id]);
    });
  }

  // Dipakai saat pelanggan yang tadinya belum bayar melunasi ketika
  // mengambil cucian: cukup baris itu yang dibenarkan.
  Future<void> notaUbahBayar(int id, int statusBayar, {int? uang}) async {
    final d = await db;
    _ringkasanUsang();
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
    bool belumLunas = false,
    String cari = '',
    int? sejakMs,
    int limit = 300,
  }) async {
    final d = await db;
    final where = <String>[];
    final args = <Object?>[];

    if (belumLunas) {
      where.add('paid = ?');
      args.add(StatusBayar.belum);
    }

    // Disaring di SQLite, bukan di Dart: menarik ribuan baris lalu
    // membuang sebagian besarnya membebani memori tanpa guna.
    if (sejakMs != null) {
      where.add('created_at >= ?');
      args.add(sejakMs);
    }

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
  // Android membatasi jumlah parameter satu query di 999. Karena itu id-nya
  // dikerjakan per potongan; tanpa ini ekspor ribuan nota gagal total
  // dengan pesan "too many SQL variables".
  static const _maksParameter = 500;

  Future<List<Nota>> notaLengkap(List<int> ids) async {
    if (ids.isEmpty) return [];
    final d = await db;

    final notas = <Nota>[];
    final perNota = <int, List<ItemNota>>{};

    for (var i = 0; i < ids.length; i += _maksParameter) {
      final akhir = (i + _maksParameter).clamp(0, ids.length);
      final potong = ids.sublist(i, akhir);
      final tanya = List.filled(potong.length, '?').join(',');

      final rows = await d.query('orders',
          where: 'id IN ($tanya)', whereArgs: potong);
      notas.addAll(rows.map(Nota.fromMap));

      final its = await d.query('order_items',
          where: 'order_id IN ($tanya)', whereArgs: potong, orderBy: 'id ASC');
      for (final r in its) {
        final it = ItemNota.fromMap(r);
        final nid = it.notaId;
        if (nid != null) (perNota[nid] ??= []).add(it);
      }
    }

    for (final n in notas) {
      n.items = perNota[n.id] ?? [];
    }
    // Urutan dikembalikan di sini karena tiap potongan diurut sendiri-sendiri.
    notas.sort((a, b) => b.dibuatMs.compareTo(a.dibuatMs));
    return notas;
  }

  // Angka untuk kartu di beranda.
  // Angka kartu hutang di beranda, disimpan di memori.
  //
  // Menghitungnya berarti membaca setiap nota yang belum lunas, jadi makin
  // lama makin berat. Yang disimpan hanya dua bilangan, bukan salinan data.
  Map<String, int>? _ringkasan;

  // Ditandai usang saat ada nota berubah, bukan langsung dihitung ulang.
  // Pada mode otomatis, hitungannya menyusul saat beranda dimuat; pada mode
  // manual, menunggu tombol perbarui ditekan.
  bool _ringkasanUsangFlag = false;

  bool get ringkasanPerluDiperbarui => _ringkasanUsangFlag;

  void _ringkasanUsang() => _ringkasanUsangFlag = true;

  // [paksa] dipakai tombol perbarui di beranda: hitung sekarang juga,
  // apa pun setelannya.
  Future<Map<String, int>> ringkasanHariIni({bool paksa = false}) async {
    final tersimpan = _ringkasan;

    if (tersimpan != null && !paksa) {
      // Sudah ada angkanya. Hitung ulang hanya kalau memang sudah usang
      // DAN pengguna memilih mode otomatis.
      final otomatis = Settings.instance.hutangOtomatis;
      if (!_ringkasanUsangFlag || !otomatis) return tersimpan;
    }

    final d = await db;

    // Nota bersaldo (total negatif) bukan hutang, jadi tidak boleh ikut
    // mengurangi jumlah yang harus ditagih.
    final hutang = await d.rawQuery(
      'SELECT COUNT(*) c, '
      'COALESCE(SUM(CASE WHEN total > 0 THEN total ELSE 0 END),0) t '
      'FROM orders WHERE paid = ?',
      [StatusBayar.belum],
    );

    int ambil(String k) {
      if (hutang.isEmpty) return 0;
      final v = hutang.first[k];
      return v is num ? v.toInt() : 0;
    }

    _ringkasanUsangFlag = false;
    return _ringkasan = {
      'belumLunasJml': ambil('c'),
      'belumLunasNilai': ambil('t'),
    };
  }

  Future<void> kosongkanTransaksi() async {
    final d = await db;
    _ringkasanUsang();
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
