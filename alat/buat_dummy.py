#!/usr/bin/env python3
"""Pembuat data uji untuk kasir laundry.

Dipakai hanya di laptop, untuk melihat apakah aplikasi masih enteng saat
notanya sudah ratusan ribu. Berkas hasilnya TIDAK ikut ke GitHub dan TIDAK
dipanggil oleh jalankan.bat mana pun.

    python alat/buat_dummy.py 100000
    python alat/buat_dummy.py 1000000 --besar
    python alat/buat_dummy.py 1000 --keluar D:\\coba.db

Setelah jadi, salin ke emulator:
    adb push dummy.db /data/local/tmp/laundry.db
    adb shell "run-as id.laundry.laundry_pos cp /data/local/tmp/laundry.db databases/laundry.db"
"""

import argparse
import os
import random
import sqlite3
import sys
import time

# Skema disalin persis dari lib/db/db.dart versi 8. Kalau skema di sana
# berubah, berkas ini ikut diperbarui, kalau tidak aplikasi akan menolak
# database buatan sini.
VERSI_SKEMA = 8

SKEMA = [
    """CREATE TABLE services(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        unit TEXT NOT NULL,
        price INTEGER NOT NULL,
        active INTEGER NOT NULL DEFAULT 1
    )""",
    """CREATE TABLE orders(
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
    )""",
    """CREATE TABLE order_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        unit TEXT NOT NULL,
        qty REAL NOT NULL,
        price INTEGER NOT NULL,
        subtotal INTEGER NOT NULL,
        FOREIGN KEY(order_id) REFERENCES orders(id) ON DELETE CASCADE
    )""",
]

# Harus sama persis dengan _buatIndeks() di lib/db/db.dart. Kurang satu
# indeks saja hasil pengukurannya menyesatkan: tanpa idx_orders_created,
# beranda terukur 74 ms padahal aplikasi sebenarnya 0,08 ms.
INDEKS = [
    "CREATE INDEX idx_orders_created ON orders(created_at DESC)",
    "CREATE INDEX idx_orders_paid ON orders(paid, created_at DESC, total)",
    "CREATE INDEX idx_orders_customer ON orders(customer)",
    "CREATE INDEX idx_items_order ON order_items(order_id)",
]

LAYANAN = [
    ("Cuci Kering Lipat", "kg", 7000),
    ("Cuci Setrika", "kg", 10000),
    ("Setrika Saja", "kg", 5000),
    ("Cuci Express 6 Jam", "kg", 15000),
    ("Bed Cover", "pcs", 35000),
    ("Selimut", "pcs", 25000),
    ("Jas / Blazer", "pcs", 30000),
    ("Sepatu", "pasang", 40000),
    ("Boneka Besar", "pcs", 45000),
    ("Gorden", "kg", 12000),
]

DEPAN = ["Budi", "Siti", "Agus", "Dewi", "Eko", "Rina", "Joko", "Ani", "Bayu",
         "Sri", "Andi", "Wati", "Rudi", "Lina", "Hadi", "Nur", "Doni", "Yuni",
         "Fajar", "Mega", "Ilham", "Putri", "Gilang", "Tari", "Bagus"]
BELAKANG = ["Santoso", "Wijaya", "Pratama", "Lestari", "Nugroho", "Saputra",
            "Rahayu", "Kusuma", "Hartono", "Maulana", "Setiawan", "Anggraini",
            "Firmansyah", "Puspita", "Ramadhan", "Safitri"]
CATATAN = ["", "", "", "", "Jangan pakai pewangi", "Pisahkan yang putih",
           "Tolong dilipat rapi", "Ada noda di kerah", "Sudah dibayar DP",
           "Diambil sore", "Titip sampai besok"]


def buat(jumlah, keluar, besar, seed):
    acak = random.Random(seed)
    if os.path.exists(keluar):
        os.remove(keluar)

    db = sqlite3.connect(keluar)
    db.execute("PRAGMA journal_mode = OFF")
    db.execute("PRAGMA synchronous = OFF")
    for s in SKEMA:
        db.execute(s)
    db.executemany(
        "INSERT INTO services(name,unit,price,active) VALUES(?,?,?,1)", LAYANAN)

    nama = [f"{acak.choice(DEPAN)} {acak.choice(BELAKANG)}"
            for _ in range(max(50, jumlah // 20))]

    sekarang = int(time.time() * 1000)
    hari = 86_400_000
    # Sebarkan ke belakang: kira-kira 40 nota per hari, jadi 100.000 nota
    # menutupi sekitar 7 tahun. Ini penting supaya filter tanggal ikut teruji.
    rentang = max(1, jumlah // 40) * hari

    nota, item = [], []
    total_semua = 0
    mulai = time.time()
    petak = 20_000

    for i in range(1, jumlah + 1):
        dibuat = sekarang - acak.randrange(rentang)
        tgl = time.strftime("%Y%m%d", time.localtime(dibuat / 1000))
        kode = f"{tgl}-{i:07d}"
        pelanggan = acak.choice(nama)

        n_item = acak.choices([1, 2, 3, 4, 5], [40, 30, 15, 10, 5])[0]
        total = 0
        baris = []
        for _ in range(n_item):
            l_nama, l_satuan, l_harga = acak.choice(LAYANAN)
            if besar:
                # Mode ekstrem: harga sengaja dinaikkan sampai belasan digit
                # untuk membuktikan kolom INTEGER tidak jebol.
                l_harga = l_harga * acak.randrange(10**7, 10**9)
            qty = (round(acak.uniform(0.5, 12.0), 1) if l_satuan == "kg"
                   else float(acak.randrange(1, 6)))
            sub = int(l_harga * qty)
            total += sub
            baris.append((l_nama, l_satuan, qty, l_harga, sub))

        lunas = 1 if acak.random() < 0.75 else 0
        tunai = total + acak.choice([0, 0, 0, 5000, 10000]) if lunas else None
        nota.append((kode, pelanggan, dibuat,
                     dibuat + acak.randrange(1, 4) * hari,
                     lunas, dibuat + 3600000 if lunas else None, tunai,
                     acak.choice(CATATAN), total, None, "{}"))
        for b in baris:
            item.append((i,) + b)
        total_semua += total

        if i % petak == 0:
            simpan(db, nota, item)
            nota, item = [], []
            lewat = time.time() - mulai
            laju = i / lewat if lewat else 0
            sisa = (jumlah - i) / laju if laju else 0
            print(f"\r  {i:,} / {jumlah:,} nota  "
                  f"({laju:,.0f}/detik, sisa {sisa:.0f} detik)   ",
                  end="", flush=True)

    simpan(db, nota, item)
    print(f"\r  {jumlah:,} / {jumlah:,} nota selesai" + " " * 30)

    print("  Membuat indeks...", end="", flush=True)
    for s in INDEKS:
        db.execute(s)
    db.execute(f"PRAGMA user_version = {VERSI_SKEMA}")
    db.commit()
    print(" selesai")

    n_item = db.execute("SELECT COUNT(*) FROM order_items").fetchone()[0]
    maks = db.execute("SELECT MAX(total) FROM orders").fetchone()[0]
    db.close()

    ukuran = os.path.getsize(keluar)
    print()
    print(f"  Berkas   : {keluar}")
    print(f"  Ukuran   : {ukuran / 1024 / 1024:,.1f} MB "
          f"({ukuran / jumlah:.0f} byte per nota)")
    print(f"  Nota     : {jumlah:,}")
    print(f"  Item     : {n_item:,}")
    print(f"  Nota terbesar : Rp{maks:,}")
    print(f"  Jumlah semua  : Rp{total_semua:,}")
    print(f"  Batas int 64  : Rp{2**63 - 1:,}")
    sisa_pakai = total_semua / (2**63 - 1) * 100
    print(f"  Terpakai dari batas: {sisa_pakai:.12f}%")
    print(f"  Waktu    : {time.time() - mulai:.1f} detik")


def simpan(db, nota, item):
    db.executemany(
        "INSERT INTO orders(code,customer,created_at,due_at,paid,paid_at,"
        "cash,note,total,print_count,extras) VALUES(?,?,?,?,?,?,?,?,?,?,?)",
        nota)
    db.executemany(
        "INSERT INTO order_items(order_id,name,unit,qty,price,subtotal) "
        "VALUES(?,?,?,?,?,?)", item)
    db.commit()


def main():
    p = argparse.ArgumentParser(
        description="Membuat database uji berisi nota acak.")
    p.add_argument("jumlah", type=int, nargs="?", default=100_000,
                   help="banyaknya nota, bawaannya 100000")
    p.add_argument("--keluar", default="dummy.db", help="nama berkas hasil")
    p.add_argument("--besar", action="store_true",
                   help="pakai harga belasan digit untuk menguji batas INTEGER")
    p.add_argument("--seed", type=int, default=42,
                   help="angka acak yang sama menghasilkan data yang sama")
    a = p.parse_args()

    if a.jumlah < 1:
        sys.exit("Jumlah nota harus 1 atau lebih.")
    if a.jumlah > 5_000_000:
        sys.exit("Di atas 5 juta nota tidak masuk akal untuk satu laundry.")

    print()
    print(f"Membuat {a.jumlah:,} nota" + (" mode BESAR" if a.besar else ""))
    print()
    buat(a.jumlah, a.keluar, a.besar, a.seed)
    print()
    print("  Data ini hanya untuk laptop. Berkas .db sudah masuk .gitignore,")
    print("  jadi tidak akan ikut terunggah ke GitHub.")
    print()


if __name__ == "__main__":
    main()
