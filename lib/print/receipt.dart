import '../models/models.dart';
import '../store/settings.dart';
import '../utils/fmt.dart';
import 'escpos.dart';

// Dipisah dari Settings supaya editor template bisa membuat pratinjau
// dari teks yang sedang diketik, tanpa harus menyimpannya dulu.
class StrukConfig {
  final String namaToko;
  final String alamatToko;
  final String teleponToko;
  final String template;
  final String templateItem;
  final int lebarKertas;
  final List<String> fieldTambahan;

  const StrukConfig({
    required this.namaToko,
    required this.alamatToko,
    required this.teleponToko,
    required this.template,
    required this.templateItem,
    required this.lebarKertas,
    this.fieldTambahan = const [],
  });

  factory StrukConfig.dari(Settings s) => StrukConfig(
        namaToko: s.namaToko,
        alamatToko: s.alamatToko,
        teleponToko: s.teleponToko,
        template: s.template,
        templateItem: s.templateItem,
        lebarKertas: s.lebarKertas,
        fieldTambahan: s.fieldTambahan,
      );

  StrukConfig salin({String? template, String? templateItem}) => StrukConfig(
        namaToko: namaToko,
        alamatToko: alamatToko,
        teleponToko: teleponToko,
        template: template ?? this.template,
        templateItem: templateItem ?? this.templateItem,
        lebarKertas: lebarKertas,
        fieldTambahan: fieldTambahan,
      );
}

// Satu baris siap cetak, sudah lepas dari template.
class BarisStruk {
  final String teks;
  final int rata;
  final bool tebal;

  // Lebar dan tinggi huruf DIPISAH, karena printer thermal memang
  // mengaturnya terpisah lewat perintah GS !.
  //
  // Inilah yang membuat ukuran "setengah" mungkin: lebar 1 tinggi 2
  // menghasilkan huruf yang lebih tinggi tapi selebar biasa, jadi tetap
  // muat 32 kolom. Perangkat kerasnya hanya mengenal kelipatan bulat
  // 1 sampai 8, jadi 1,5 kali lebar tidak akan pernah bisa.
  final int skalaLebar;
  final int skalaTinggi;

  const BarisStruk(
    this.teks, {
    this.rata = EscPos.rataKiri,
    this.tebal = false,
    int skala = 1,
    int? skalaLebar,
    int? skalaTinggi,
  })  : skalaLebar = skalaLebar ?? skala,
        skalaTinggi = skalaTinggi ?? skala;

  // Lebar yang menentukan berapa karakter yang muat dalam satu baris.
  int get skala => skalaLebar;

  bool get besar => skalaLebar > 1 || skalaTinggi > 1;
}

// Mesin template struk.
//
// Tag di awal baris, boleh digabung seperti [B][C] atau [BC]:
//   [L] kiri   [C] tengah   [R] kanan   [B] tebal   [H] huruf dobel
//   [?kunci] lewati baris ini bila {kunci} kosong atau berisi '-'
// Tag di tengah baris:
//   [>] dorong sisanya ke kanan, untuk "TOTAL ....... Rp50.000"
// Baris berisi --- atau === menjadi garis pemisah selebar kertas.
class Struk {
  // Titik dan koma ikut diterima supaya [C1.5] terbaca sebagai tag.
  static final _tag = RegExp(r'^\[([A-Za-z0-9.,]{1,8})\]');
  static final _garis = RegExp(r'^(-{3,}|={3,}|\*{3,})$');
  static final _syarat = RegExp(r'^\[\?([a-z0-9_]+)\]');

  // Ditampilkan sebagai daftar bantuan di editor template.
  static const placeholderNota = {
    '{nama_toko}': 'Nama laundry',
    '{alamat_toko}': 'Alamat laundry',
    '{telepon_toko}': 'Telepon / WA',
    '{no_nota}': 'Nomor nota',
    '{tanggal}': 'Tanggal nota',
    '{jam}': 'Jam nota',
    '{hari}': 'Nama hari',
    '{nama_pelanggan}': 'Nama pelanggan',
    '{estimasi}': 'Estimasi selesai, kosong bila tidak dipakai',
    '{status_bayar}': 'LUNAS / BELUM BAYAR, kosong bila disembunyikan',
    '{uang}': 'Uang diterima, kosong bila tidak diisi',
    '{kembalian}': 'Kembalian, kosong bila uang tidak diisi',
    '{label_kembalian}': 'Kata "Kembali" atau "Kurang", ikut keadaan nota',
    '{total}': 'Total harga, selalu positif',
    '{label_total}': 'Tulisan TOTAL, jadi SISA SALDO bila minus',
    '{total_asli}': 'Total apa adanya, termasuk tanda minus',
    '{jumlah_item}': 'Banyaknya baris item',
    '{catatan}': 'Catatan nota',
    '{salinan}': 'Judul salinan, misal PELANGGAN / ARSIP TOKO',
    '{salinan_ke}': 'Nomor salinan, 1 atau 2',
    '{daftar_item}': 'Tempat daftar item dicetak',
  };

  static const placeholderItem = {
    '{no}': 'Nomor urut item',
    '{nama_item}': 'Nama layanan',
    '{qty}': 'Jumlah',
    '{satuan}': 'kg / pcs / satuan bebas',
    '{qty_satuan}': 'Jumlah + satuan, rapi walau satuan kosong',
    '{harga}': 'Harga satuan',
    '{subtotal}': 'Harga x jumlah',
  };

  // Ubah nota jadi daftar baris siap cetak. [salinan] mengisi {salinan},
  // untuk membedakan lembar pelanggan dan lembar arsip toko.
  static List<BarisStruk> render(
    Nota nota,
    StrukConfig s, {
    String salinan = '',
    int salinanKe = 1,
  }) {
    final lebar = s.lebarKertas;
    final vars = _varsNota(nota, s, salinan: salinan, salinanKe: salinanKe);

    final barisItem = <BarisStruk>[];
    for (var i = 0; i < nota.items.length; i++) {
      final v = _varsItem(nota.items[i], i + 1);
      for (final raw in s.templateItem.split('\n')) {
        barisItem.addAll(_renderBaris(_parseTag(raw), v, lebar));
      }
    }

    final hasil = <BarisStruk>[];
    for (final raw in s.template.split('\n')) {
      final p = _parseTag(raw);
      if (p.teks.trim() == '{daftar_item}') {
        hasil.addAll(barisItem);
      } else {
        hasil.addAll(_renderBaris(p, vars, lebar));
      }
    }
    return hasil;
  }

  // Meratakan baris siap cetak menjadi teks polos.
  //
  // Dipakai untuk berbagi nota lewat chat. Ukuran huruf hilang di sini
  // karena teks biasa tidak mengenalnya; yang dipertahankan perataan dan
  // lebar kolomnya. Hanya ada SATU fungsi ini supaya tidak ada dua
  // aturan yang perlahan berbeda.
  static String pratinjau(List<BarisStruk> baris, int lebar,
      {bool rapikan = false}) {
    final buf = StringBuffer();
    for (final b in baris) {
      final efektif = lebarEfektif(lebar, b.skala);
      var t = b.teks;
      if (t.length > efektif) t = t.substring(0, efektif);

      // Baris berskala dipetakan kembali ke lebar kertas penuh.
      //
      // Di kertas, [B2] memakai 16 kolom tapi hurufnya dua kali lebar,
      // jadi tetap memenuhi 32 kolom. Teks biasa tidak punya ukuran
      // huruf, sehingga 16 kolom apa adanya terlihat menggantung di kiri
      // dan tidak sejajar dengan baris lain. Perataannya karena itu
      // dihitung terhadap lebar kertas penuh.
      final ruang = b.skala > 1 ? lebar : efektif;

      if (b.rata == EscPos.rataTengah) {
        t = ' ' * ((ruang - t.length) ~/ 2) + t;
      } else if (b.rata == EscPos.rataKanan) {
        t = ' ' * (ruang - t.length) + t;
      } else if (b.skala > 1) {
        // Baris rata kiri berskala yang memakai [>] sudah berisi spasi
        // pengatur di tengahnya. Spasinya dilebarkan sebanding, supaya
        // kolom kanannya tetap mentok ke kanan.
        t = _regangkan(t, ruang);
      }
      buf.writeln(rapikan ? t.trimRight() : t);
    }
    final hasil = buf.toString();
    return rapikan ? hasil.trimRight() : hasil;
  }

  // #Melebarkan celah spasi terpanjang supaya baris pas selebar [lebar]
  static String _regangkan(String t, int lebar) {
    if (t.length >= lebar) return t;
    final celah = RegExp(r'\s{2,}').allMatches(t).toList();
    if (celah.isEmpty) return t;
    // Celah terpanjang dianggap sebagai hasil tag [>].
    final c = celah.reduce((a, b) =>
        (b.end - b.start) > (a.end - a.start) ? b : a);
    final tambah = lebar - t.length;
    return t.substring(0, c.start) +
        ' ' * (c.end - c.start + tambah) +
        t.substring(c.end);
  }

  // Huruf berskala 2 memakan dua kali lebar, jadi kolomnya tinggal separuh.
  // Berapa karakter yang muat pada satu baris berskala [skala].
  //
  // Batas atasnya lebar kertas itu sendiri, bukan kLebarMaks. Dengan
  // kLebarMaks, kertas sempit bisa menerima baris lebih panjang daripada
  // kertasnya dan hasilnya melewati tepi.
  static int lebarEfektif(int lebar, int skala) =>
      (lebar ~/ skala.clamp(1, 8)).clamp(1, lebar);

  // Panjang garis pemisah supaya benar-benar mengisi lebar kertas.
  //
  // Baris berskala memakai lebih sedikit karakter, tapi tiap karakternya
  // selebar [skala] kolom. Pembagian yang tidak bulat menyisakan ruang
  // kosong di ujung kanan: pada kertas 32 dengan skala 3, 10 karakter
  // hanya menutup 30 kolom. Sisanya ditambal dengan menaikkan panjangnya
  // satu karakter selama masih muat.
  static int panjangGaris(int lebar, int skala) {
    final s = skala.clamp(1, 8);
    final dasar = lebarEfektif(lebar, s);
    // Tambah satu hanya bila hasilnya tetap tidak melewati kertas.
    return (dasar + 1) * s <= lebar ? dasar + 1 : dasar;
  }

  static Map<String, String> _varsNota(
    Nota n,
    StrukConfig s, {
    String salinan = '',
    int salinanKe = 1,
  }) {
    final d = n.dibuat;

    // Field buatan pengguna: "Parfum" dipakai di template sebagai {parfum}.
    final ekstra = <String, String>{};
    for (final label in s.fieldTambahan) {
      final nilai = (n.ekstra[Settings.kunciField(label)] ?? '').trim();
      ekstra['{${Settings.kunciField(label)}}'] = nilai.isEmpty ? '-' : nilai;
    }

    final uang = n.uangDibayar;
    // Selalu positif; yang menyatakan arahnya {label_kembalian}.
    final kembali = n.nilaiKembalian;

    return {
      ...ekstra,
      '{salinan}': salinan,
      '{salinan_ke}': salinanKe.toString(),
      '{nama_toko}': s.namaToko,
      '{alamat_toko}': s.alamatToko,
      '{telepon_toko}': s.teleponToko,
      '{no_nota}': n.kode,
      '{tanggal}': tanggal(d),
      '{jam}': jam(d),
      '{hari}': hari(d),
      '{nama_pelanggan}': n.pelanggan,
      // Yang berikut sengaja dikosongkan, bukan diisi '-', supaya
      // barisnya bisa dilewati dengan tag [?...] dan kertas tidak terbuang.
      '{estimasi}': n.estimasi == null ? '' : tanggal(n.estimasi!),
      '{status_bayar}': StatusBayar.teksStruk(n.statusBayar),
      '{uang}': uang == null ? '' : rupiah(uang),
      '{kembalian}': kembali == null ? '' : rupiah(kembali),
      '{label_kembalian}': kembali == null ? '' : n.labelKembalian,
      '{total}': rupiah(n.nilaiTampil),
      '{label_total}': n.labelTotal,
      '{total_asli}': rupiah(n.total),
      '{jumlah_item}': n.items.length.toString(),
      '{catatan}': n.catatan.trim().isEmpty ? '-' : n.catatan.trim(),
    };
  }

  static Map<String, String> _varsItem(ItemNota it, int no) {
    final qty = qtyStr(it.qty);
    return {
      '{no}': no.toString(),
      '{nama_item}': it.nama,
      '{qty}': qty,
      '{satuan}': it.satuan.trim(),
      '{qty_satuan}': Satuan.gabung(qty, it.satuan),
      '{harga}': rupiah(it.harga),
      '{subtotal}': rupiah(it.subtotal),
    };
  }

  static String _isi(String teks, Map<String, String> vars) {
    var out = teks;
    vars.forEach((k, v) => out = out.replaceAll(k, v));
    return out;
  }

  static List<BarisStruk> _renderBaris(
      _Parsed p, Map<String, String> vars, int lebar) {
    final syarat = p.syarat;
    if (syarat != null) {
      final nilai = (vars['{$syarat}'] ?? '').trim();
      if (nilai.isEmpty || nilai == '-') return const [];
    }

    final efektif = lebarEfektif(lebar, p.skala);

    // Diubah ke ASCII lebih dulu, karena lebar cetak dihitung dari hasil
    // konversi. Tanpa ini, satu karakter seperti '…' yang jadi '...'
    // membuat perataan kiri-kanan meleset.
    final teks = EscPos.keAscii(_isi(p.teks, vars));

    final t = teks.trim();
    if (t.isNotEmpty && _garis.hasMatch(t)) {
      return [
        BarisStruk(t[0] * panjangGaris(lebar, p.skala),
            tebal: p.tebal,
            skalaLebar: p.skalaLebar,
            skalaTinggi: p.skalaTinggi)
      ];
    }

    final pisah = teks.indexOf('[>]');
    if (pisah >= 0) {
      final kiri = teks.substring(0, pisah);
      final kanan = teks.substring(pisah + 3);
      final sisa = efektif - kiri.length - kanan.length;

      if (sisa >= 1) {
        return [
          BarisStruk(kiri + ' ' * sisa + kanan,
              tebal: p.tebal,
              skalaLebar: p.skalaLebar,
              skalaTinggi: p.skalaTinggi)
        ];
      }
      // Tidak muat sebaris: kiri di atas, kanan rata kanan di bawahnya.
      return [
        for (final l in _bungkus(kiri, efektif))
          BarisStruk(l,
              tebal: p.tebal,
              skalaLebar: p.skalaLebar,
              skalaTinggi: p.skalaTinggi),
        BarisStruk(kanan,
            rata: EscPos.rataKanan,
            tebal: p.tebal,
            skalaLebar: p.skalaLebar,
            skalaTinggi: p.skalaTinggi),
      ];
    }

    // Baris kosong dipertahankan, dipakai untuk mengatur jarak.
    if (teks.isEmpty) {
      return [
        BarisStruk('',
            rata: p.rata,
            tebal: p.tebal,
            skalaLebar: p.skalaLebar,
            skalaTinggi: p.skalaTinggi)
      ];
    }

    return [
      for (final l in _bungkus(teks, efektif))
        BarisStruk(l,
            rata: p.rata,
            tebal: p.tebal,
            skalaLebar: p.skalaLebar,
            skalaTinggi: p.skalaTinggi),
    ];
  }

  // Pecah teks panjang per kata agar muat di lebar kertas.
  static List<String> _bungkus(String teks, int lebar) {
    if (lebar <= 0 || teks.length <= lebar) return [teks];

    final out = <String>[];
    var baris = '';

    for (final kata in teks.split(' ')) {
      if (kata.length > lebar) {
        if (baris.isNotEmpty) {
          out.add(baris);
          baris = '';
        }
        var sisa = kata;
        while (sisa.length > lebar) {
          out.add(sisa.substring(0, lebar));
          sisa = sisa.substring(lebar);
        }
        baris = sisa;
      } else if (baris.isEmpty) {
        baris = kata;
      } else if (baris.length + 1 + kata.length <= lebar) {
        baris = '$baris $kata';
      } else {
        out.add(baris);
        baris = kata;
      }
    }
    if (baris.isNotEmpty) out.add(baris);
    return out;
  }

  static _Parsed _parseTag(String raw) {
    var s = raw;
    var rata = EscPos.rataKiri;
    var tebal = false;
    var skalaLebar = 1;
    var skalaTinggi = 1;
    String? syarat;

    // [?kunci] dibaca lebih dulu karena bentuknya berbeda dari tag biasa.
    final ms = _syarat.firstMatch(s);
    if (ms != null) {
      syarat = ms.group(1);
      s = s.substring(ms.end);
    }

    while (true) {
      final m = _tag.firstMatch(s);
      if (m == null) break;
      final isi = m.group(1)!.toUpperCase();

      // Angka di dalam tag berarti ukuran huruf: [C2] tengah ukuran dua.
      // Boleh pecahan, misalnya [C1.5], dan dibaca sebagai satu bilangan
      // supaya [H10] tidak terbaca 1 lalu 0.
      //
      // Pecahan diwujudkan sebagai huruf yang lebih TINGGI tanpa
      // melebar: 1,5 menjadi lebar 1 tinggi 2. Printer thermal hanya
      // mengenal kelipatan bulat untuk lebar maupun tinggi, jadi 1,5
      // kali lebar memang tidak mungkin, tapi 1,5 kali "besar" secara
      // penampilan bisa. Untungnya baris seperti itu tetap muat 32
      // kolom, tidak seperti [C2] yang cuma muat 16.
      final angka = RegExp(r'\d+(?:[.,]\d+)?').firstMatch(isi);
      if (angka != null) {
        final n = double.tryParse(angka.group(0)!.replaceAll(',', '.')) ?? 1.0;
        final utuh = n.floor().clamp(1, 8);
        skalaLebar = utuh;
        // Sisa pecahan 0,5 ke atas dibulatkan menjadi satu tingkat
        // tinggi tambahan.
        skalaTinggi = (n - n.floor() >= 0.5 ? utuh + 1 : utuh).clamp(1, 8);
      }

      for (final c in isi.replaceAll(RegExp(r'[\d.,]'), '').split('')) {
        switch (c) {
          case 'L':
            rata = EscPos.rataKiri;
          case 'C':
            rata = EscPos.rataTengah;
          case 'R':
            rata = EscPos.rataKanan;
          case 'B':
            tebal = true;
          case 'H':
            // [H] tanpa angka tetap berarti dua kali besar, seperti dulu.
            if (angka == null) {
              skalaLebar = 2;
              skalaTinggi = 2;
            }
        }
      }
      s = s.substring(m.end);
    }
    return _Parsed(s, rata, tebal, skalaLebar, skalaTinggi, syarat);
  }
}

class _Parsed {
  final String teks;
  final int rata;
  final bool tebal;
  final int skalaLebar;
  final int skalaTinggi;
  final String? syarat;

  const _Parsed(this.teks, this.rata, this.tebal, this.skalaLebar,
      this.skalaTinggi, this.syarat);

  // Lebar yang menentukan berapa karakter muat dalam satu baris.
  int get skala => skalaLebar;
}
