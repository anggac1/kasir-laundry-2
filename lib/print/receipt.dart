import '../models/models.dart';
import '../store/settings.dart';
import '../utils/fmt.dart';

/// Konfigurasi yang dibutuhkan mesin struk.
///
/// Sengaja dipisah dari [Settings] supaya editor template bisa membuat
/// pratinjau dari teks yang sedang diketik, tanpa harus menyimpannya dulu.
class StrukConfig {
  final String namaToko;
  final String alamatToko;
  final String teleponToko;
  final String template;
  final String templateItem;
  final int lebarKertas;

  /// Nama field tambahan buatan pengguna, misalnya ["Parfum", "Jenis Cucian"].
  final List<String> fieldTambahan;

  const StrukConfig({
    required this.namaToko,
    required this.alamatToko,
    required this.teleponToko,
    required this.template,
    required this.templateItem,
    required this.lebarKertas,
    this.fieldTambahan = const <String>[],
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

/// Satu baris siap cetak, sudah lepas dari template.
class BarisStruk {
  final String teks;

  /// 0 = kiri, 1 = tengah, 2 = kanan
  final int rata;
  final bool tebal;
  final bool besar;

  const BarisStruk(this.teks,
      {this.rata = 0, this.tebal = false, this.besar = false});
}

/// Mesin template struk.
///
/// Tag di awal baris (boleh digabung, contoh `[B][C]` atau `[BC]`):
///   [L] rata kiri    [C] rata tengah    [R] rata kanan
///   [B] tebal        [H] huruf besar (dobel)
///
/// Tag di tengah baris:
///   [>] dorong sisa teks ke kanan, dipakai untuk "TOTAL ....... Rp50.000"
///
/// Baris berisi `---` atau `===` menjadi garis pemisah selebar kertas.
class Struk {
  static final RegExp _tag = RegExp(r'^\[([A-Za-z]{1,4})\]');
  static final RegExp _garis = RegExp(r'^(-{3,}|={3,}|\*{3,})$');

  /// Tag syarat: [?kunci] di awal baris.
  /// Baris dilewati sama sekali kalau {kunci} kosong atau berisi '-'.
  /// Berguna supaya baris Uang dan Kembalian tidak ikut tercetak
  /// saat tidak diisi, jadi kertas tidak terbuang.
  static final RegExp _syarat = RegExp(r'^\[\?([a-z0-9_]+)\]');

  /// Daftar placeholder untuk ditampilkan di editor template.
  static const placeholderNota = <String, String>{
    '{nama_toko}': 'Nama laundry',
    '{alamat_toko}': 'Alamat laundry',
    '{telepon_toko}': 'Telepon / WA',
    '{no_nota}': 'Nomor nota',
    '{tanggal}': 'Tanggal nota',
    '{jam}': 'Jam nota',
    '{hari}': 'Nama hari',
    '{nama_pelanggan}': 'Nama pelanggan',
    '{estimasi}': 'Estimasi selesai, kosong bila tidak dipakai',
    '{status_pesanan}': 'Diterima / Diproses / Selesai / Diambil',
    '{status_bayar}': 'LUNAS / BELUM BAYAR, kosong bila disembunyikan',
    '{uang}': 'Uang diterima, kosong bila tidak diisi',
    '{kembalian}': 'Kembalian, kosong bila uang tidak diisi',
    '{total}': 'Total harga, selalu positif',
    '{label_total}': 'Tulisan TOTAL, berubah jadi SISA SALDO bila minus',
    '{total_asli}': 'Total apa adanya, termasuk tanda minus',
    '{jumlah_item}': 'Banyaknya baris item',
    '{catatan}': 'Catatan nota',
    '{salinan}': 'Judul salinan, misal PELANGGAN / ARSIP TOKO',
    '{salinan_ke}': 'Nomor salinan, 1 atau 2',
    '{daftar_item}': 'Tempat daftar item dicetak',
  };

  static const placeholderItem = <String, String>{
    '{no}': 'Nomor urut item',
    '{nama_item}': 'Nama layanan',
    '{qty}': 'Jumlah',
    '{satuan}': 'kg / pcs / satuan bebas',
    '{qty_satuan}': 'Jumlah + satuan, rapi walau satuan kosong',
    '{harga}': 'Harga satuan',
    '{subtotal}': 'Harga x jumlah',
  };

  static Map<String, String> _varsNota(
    Nota n,
    StrukConfig s, {
    String salinan = '',
    int salinanKe = 1,
  }) {
    final d = n.dibuat;

    // Field tambahan buatan pengguna.
    // Nama field "Parfum" bisa dipakai di template sebagai {parfum}.
    final ekstra = <String, String>{};
    for (final label in s.fieldTambahan) {
      final kunci = Settings.kunciField(label);
      final nilai = (n.ekstra[kunci] ?? '').trim();
      ekstra['{$kunci}'] = nilai.isEmpty ? '-' : nilai;
    }

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
      // Kosong, bukan '-', supaya barisnya bisa dilewati dengan
      // tag [?estimasi] saat nota dibuat di akhir.
      '{estimasi}': n.estimasi == null ? '' : tanggal(n.estimasi!),
      '{status_pesanan}': StatusPesanan.label(n.status),
      // Kosong kalau pengguna memilih menyembunyikan status pembayaran.
      '{status_bayar}': StatusBayar.teksStruk(n.statusBayar),
      // Kosong kalau uang tidak diisi, sehingga barisnya bisa dilewati
      // dengan tag [?uang] dan kertas tidak terbuang.
      '{uang}': n.uangDibayar == null ? '' : rupiah(n.uangDibayar!),
      '{kembalian}': n.kembalian == null ? '' : rupiah(n.kembalian!),
      // Total selalu dicetak positif. Kalau negatif, dikalikan -1 dan
      // labelnya berubah jadi SISA SALDO, jadi maknanya tetap jelas
      // tanpa perlu tanda minus di struk.
      '{total}': rupiah(n.nilaiTampil),
      '{label_total}': n.labelTotal,
      '{total_asli}': rupiah(n.total),
      '{jumlah_item}': n.items.length.toString(),
      '{catatan}': n.catatan.trim().isEmpty ? '-' : n.catatan.trim(),
    };
  }

  static Map<String, String> _varsItem(ItemNota it, int no) => {
        '{no}': no.toString(),
        '{nama_item}': it.nama,
        '{qty}': qtyStr(it.qty),
        '{satuan}': it.satuan.trim(),
        // Gabungan qty dan satuan, sudah rapi kalau satuannya kosong.
        // "3.5 kg", "2 botol", atau cuma "1" untuk baris tanpa satuan
        // seperti hutang dan saldo.
        '{qty_satuan}': Satuan.gabung(qtyStr(it.qty), it.satuan),
        '{harga}': rupiah(it.harga),
        '{subtotal}': rupiah(it.subtotal),
      };

  static String _isi(String teks, Map<String, String> vars) {
    var out = teks;
    vars.forEach((k, v) => out = out.replaceAll(k, v));
    return out;
  }

  /// Ubah nota menjadi daftar baris siap cetak.
  ///
  /// [salinan] mengisi placeholder {salinan}, dipakai untuk membedakan
  /// lembar pelanggan dan lembar arsip toko.
  static List<BarisStruk> render(
    Nota nota,
    StrukConfig s, {
    String salinan = '',
    int salinanKe = 1,
  }) {
    final lebar = s.lebarKertas;
    final vars =
        _varsNota(nota, s, salinan: salinan, salinanKe: salinanKe);

    // Render dulu semua baris item.
    final barisItem = <BarisStruk>[];
    for (var i = 0; i < nota.items.length; i++) {
      final v = _varsItem(nota.items[i], i + 1);
      barisItem.addAll(_renderBlok(s.templateItem, v, lebar));
    }

    final hasil = <BarisStruk>[];
    for (final raw in s.template.split('\n')) {
      final parsed = _parseTag(raw);
      if (parsed.teks.trim() == '{daftar_item}') {
        hasil.addAll(barisItem);
        continue;
      }
      hasil.addAll(_renderBaris(parsed, vars, lebar));
    }
    return hasil;
  }

  static List<BarisStruk> _renderBlok(
      String tpl, Map<String, String> vars, int lebar) {
    final out = <BarisStruk>[];
    for (final raw in tpl.split('\n')) {
      out.addAll(_renderBaris(_parseTag(raw), vars, lebar));
    }
    return out;
  }

  static List<BarisStruk> _renderBaris(
      _Parsed p, Map<String, String> vars, int lebar) {
    // Baris bersyarat: lewati kalau nilainya kosong atau '-'.
    if (p.syarat != null) {
      final nilai = (vars['{${p.syarat}}'] ?? '').trim();
      if (nilai.isEmpty || nilai == '-') return const <BarisStruk>[];
    }

    final efektif = p.besar ? (lebar ~/ 2) : lebar;
    var teks = _isi(p.teks, vars);

    // Garis pemisah.
    final t = teks.trim();
    if (_garis.hasMatch(t)) {
      return [
        BarisStruk(t[0] * efektif,
            rata: 0, tebal: p.tebal, besar: p.besar)
      ];
    }

    // Dorong ke kanan: "KIRI[>]KANAN"
    if (teks.contains('[>]')) {
      final idx = teks.indexOf('[>]');
      final kiri = teks.substring(0, idx);
      final kanan = teks.substring(idx + 3);
      final sisa = efektif - kiri.length - kanan.length;
      if (sisa >= 1) {
        return [
          BarisStruk(kiri + ' ' * sisa + kanan,
              rata: 0, tebal: p.tebal, besar: p.besar)
        ];
      }
      // Tidak muat: kiri di baris atas, kanan rata kanan di bawahnya.
      return [
        ..._bungkus(kiri, efektif)
            .map((l) => BarisStruk(l, rata: 0, tebal: p.tebal, besar: p.besar)),
        BarisStruk(kanan, rata: 2, tebal: p.tebal, besar: p.besar),
      ];
    }

    // Baris kosong tetap dipertahankan (untuk mengatur jarak).
    if (teks.isEmpty) {
      return [BarisStruk('', rata: p.rata, tebal: p.tebal, besar: p.besar)];
    }

    return _bungkus(teks, efektif)
        .map((l) =>
            BarisStruk(l, rata: p.rata, tebal: p.tebal, besar: p.besar))
        .toList();
  }

  /// Potong teks panjang agar muat di lebar kertas, pecah per kata.
  static List<String> _bungkus(String teks, int lebar) {
    if (lebar <= 0) return [teks];
    if (teks.length <= lebar) return [teks];
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
        continue;
      }
      if (baris.isEmpty) {
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
    var rata = 0;
    var tebal = false;
    var besar = false;
    String? syarat;

    // Tag syarat harus dibaca lebih dulu karena bentuknya [?...]
    final ms = _syarat.firstMatch(s);
    if (ms != null) {
      syarat = ms.group(1);
      s = s.substring(ms.end);
    }

    while (true) {
      final m = _tag.firstMatch(s);
      if (m == null) break;
      for (final c in m.group(1)!.toUpperCase().split('')) {
        switch (c) {
          case 'L':
            rata = 0;
            break;
          case 'C':
            rata = 1;
            break;
          case 'R':
            rata = 2;
            break;
          case 'B':
            tebal = true;
            break;
          case 'H':
            besar = true;
            break;
        }
      }
      s = s.substring(m.end);
    }
    return _Parsed(s, rata, tebal, besar, syarat);
  }

  /// Pratinjau teks polos, dipakai di editor template.
  /// Perataan dikerjakan dengan spasi supaya tampak seperti hasil cetak.
  static String pratinjau(List<BarisStruk> baris, int lebar) {
    final buf = StringBuffer();
    for (final b in baris) {
      final efektif = b.besar ? (lebar ~/ 2) : lebar;
      var t = b.teks;
      if (t.length > efektif) t = t.substring(0, efektif);
      if (b.rata == 1) {
        final kiri = ((efektif - t.length) / 2).floor();
        t = ' ' * kiri + t;
      } else if (b.rata == 2) {
        t = ' ' * (efektif - t.length) + t;
      }
      buf.writeln(t);
    }
    return buf.toString();
  }
}

class _Parsed {
  final String teks;
  final int rata;
  final bool tebal;
  final bool besar;

  /// Kunci placeholder yang harus terisi agar baris ini dicetak.
  final String? syarat;

  const _Parsed(this.teks, this.rata, this.tebal, this.besar, this.syarat);
}
