import 'dart:async';

import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../models/models.dart';
import '../store/settings.dart';
import 'escpos.dart';
import 'receipt.dart';

class HasilCetak {
  final bool sukses;
  final String pesan;

  /// Catatan tiap langkah, untuk ditampilkan kalau gagal.
  final List<String> langkah;

  const HasilCetak(this.sukses, this.pesan, [this.langkah = const []]);

  String get rincian => langkah.join('\n');
}

/// Ringkasan keadaan Bluetooth, dipakai layar printer untuk
/// menjelaskan ke pengguna apa yang sedang salah.
class DiagnosaPrinter {
  final bool bluetoothMenyala;
  final bool izinDiberikan;
  final String catatan;
  final List<BluetoothInfo> perangkat;

  const DiagnosaPrinter({
    required this.bluetoothMenyala,
    required this.izinDiberikan,
    required this.catatan,
    required this.perangkat,
  });
}

/// Catatan percetakan terakhir, dipakai layar Debug.
class JejakCetak {
  final String waktu;
  final String kodeNota;
  final int jumlahSalinan;
  final String teksStruk;
  final List<int> bytes;
  final String hasil;
  final List<String> langkah;

  const JejakCetak({
    required this.waktu,
    required this.kodeNota,
    required this.jumlahSalinan,
    required this.teksStruk,
    required this.bytes,
    required this.hasil,
    this.langkah = const [],
  });
}

/// Pembungkus printer thermal Bluetooth Classic (SPP).
///
/// Dirancang untuk printer 58mm murah seperti RPP02N, yang punya dua
/// kebiasaan merepotkan: gampang menolak kiriman data besar sekaligus,
/// dan kadang melaporkan masih tersambung padahal soketnya sudah mati.
///
/// Semua panggilan ke lapisan Android dibatasi waktunya. Tanpa ini,
/// satu panggilan yang menggantung membuat layar berputar selamanya
/// karena Future-nya tidak pernah selesai dan tidak melempar error.
class PrinterService {
  PrinterService._();
  static final PrinterService instance = PrinterService._();

  static const _batas = Duration(seconds: 8);

  /// Dialog izin sistem tidak boleh ditunggu terlalu lama. Sebelumnya
  /// 60 detik, dan dikali tiga permintaan hasilnya terasa seperti
  /// aplikasi menggantung.
  static const _batasIzin = Duration(seconds: 25);

  /// Potongan kiriman ke printer. Printer SPP murah punya buffer kecil,
  /// kiriman besar sekaligus sering diterima separuh lalu berhenti.
  static const _ukuranPotongan = 512;

  JejakCetak? jejakTerakhir;

  Future<T> _aman<T>(
    Future<T> Function() jalankan,
    T cadangan, {
    Duration batas = _batas,
  }) async {
    try {
      return await jalankan().timeout(batas);
    } on TimeoutException {
      return cadangan;
    } catch (_) {
      return cadangan;
    }
  }

  // ------------------------------------------------------------------ izin

  Future<PermissionStatus> _status(Permission p) async {
    try {
      return await p.status.timeout(const Duration(seconds: 4));
    } catch (_) {
      return PermissionStatus.denied;
    }
  }

  Future<PermissionStatus> _minta(Permission p) async {
    try {
      return await p.request().timeout(_batasIzin);
    } catch (_) {
      return PermissionStatus.denied;
    }
  }

  /// Android 12+ memakai BLUETOOTH_CONNECT dan BLUETOOTH_SCAN.
  /// Android 11 ke bawah memakai izin lokasi.
  /// Izin yang tidak berlaku di versi Android tertentu langsung ditolak
  /// sistem, dan itu normal, bukan tanda kegagalan.
  Future<bool> mintaIzin() async {
    final connect = await _minta(Permission.bluetoothConnect);
    if (connect.isGranted) {
      await _minta(Permission.bluetoothScan);
      return true;
    }
    final lokasi = await _minta(Permission.location);
    return lokasi.isGranted;
  }

  Future<bool> izinSudahAda() async {
    final connect = await _status(Permission.bluetoothConnect);
    if (connect.isGranted) return true;
    final lokasi = await _status(Permission.location);
    return lokasi.isGranted;
  }

  Future<void> bukaPengaturanAplikasi() async {
    await _aman(() => openAppSettings(), false);
  }

  // -------------------------------------------------------------- bluetooth

  Future<bool> bluetoothAktif() =>
      _aman(() => PrintBluetoothThermal.bluetoothEnabled, false);

  Future<List<BluetoothInfo>> daftarPrinter() =>
      _aman(() => PrintBluetoothThermal.pairedBluetooths, <BluetoothInfo>[]);

  Future<bool> terhubung() =>
      _aman(() => PrintBluetoothThermal.connectionStatus, false);

  Future<void> putuskan() async {
    await _aman(() => PrintBluetoothThermal.disconnect, false);
  }

  /// Sambung ke printer, dicoba beberapa kali.
  ///
  /// Sambungan lama selalu diputus lebih dulu. Printer seperti RPP02N
  /// kadang melaporkan status masih tersambung padahal soketnya sudah
  /// mati sejak printer dimatikan, dan menulis ke soket mati itu gagal
  /// tanpa pesan apa pun.
  Future<bool> hubungkan(String mac, {List<String>? catatan}) async {
    for (var percobaan = 1; percobaan <= 3; percobaan++) {
      await putuskan();
      await Future.delayed(const Duration(milliseconds: 300));

      final ok = await _aman(
        () => PrintBluetoothThermal.connect(macPrinterAddress: mac),
        false,
        batas: const Duration(seconds: 12),
      );

      if (ok) {
        catatan?.add('Sambung ke printer: berhasil (percobaan $percobaan)');
        // Sebagian printer butuh jeda sebelum siap menerima data.
        await Future.delayed(const Duration(milliseconds: 400));
        return true;
      }

      catatan?.add('Sambung ke printer: gagal (percobaan $percobaan)');
      await Future.delayed(const Duration(milliseconds: 600));
    }
    return false;
  }

  /// Kirim byte sedikit demi sedikit.
  ///
  /// Printer thermal murah punya buffer beberapa ratus byte saja.
  /// Struk dua salinan bisa lebih dari 2 KB, dan kalau dikirim sekaligus
  /// sering tercetak separuh lalu berhenti, atau tidak tercetak sama sekali.
  Future<bool> _tulisBertahap(List<int> bytes, {List<String>? catatan}) async {
    var terkirim = 0;
    for (var i = 0; i < bytes.length; i += _ukuranPotongan) {
      final akhir = (i + _ukuranPotongan > bytes.length)
          ? bytes.length
          : i + _ukuranPotongan;

      final ok = await _aman(
        () => PrintBluetoothThermal.writeBytes(bytes.sublist(i, akhir)),
        false,
        batas: const Duration(seconds: 12),
      );

      if (!ok) {
        catatan?.add('Kirim data: gagal di byte ke-$terkirim '
            'dari ${bytes.length}');
        return false;
      }

      terkirim = akhir;
      // Jeda kecil supaya buffer printer sempat kosong.
      await Future.delayed(const Duration(milliseconds: 20));
    }
    catatan?.add('Kirim data: berhasil ($terkirim byte)');
    return true;
  }

  /// Kumpulkan keadaan lengkap dalam satu panggilan.
  /// Dijamin selesai, tidak akan menggantung.
  Future<DiagnosaPrinter> periksa({bool mintaIzinDulu = false}) async {
    var izin = await izinSudahAda();
    if (!izin && mintaIzinDulu) izin = await mintaIzin();

    final menyala = await bluetoothAktif();
    final perangkat = izin ? await daftarPrinter() : <BluetoothInfo>[];

    String catatan;
    if (!izin) {
      catatan = 'Izin Bluetooth belum diberikan.';
    } else if (!menyala) {
      catatan = 'Bluetooth di HP masih mati.';
    } else if (perangkat.isEmpty) {
      catatan = 'Belum ada perangkat Bluetooth yang dipasangkan di HP ini.';
    } else {
      catatan = '${perangkat.length} perangkat terpasang ditemukan.';
    }

    return DiagnosaPrinter(
      bluetoothMenyala: menyala,
      izinDiberikan: izin,
      catatan: catatan,
      perangkat: perangkat,
    );
  }

  // ----------------------------------------------------------------- cetak

  /// Mengirim ke printer sambil mencatat tiap langkah, supaya kalau
  /// gagal bisa terlihat persis berhenti di tahap mana.
  Future<HasilCetak> kirim(List<int> bytes) async {
    final s = Settings.instance;
    final catatan = <String>[];
    final mac = s.printerMac;

    catatan.add('Printer tersimpan: ${s.printerNama ?? "-"} '
        '(${mac ?? "belum dipilih"})');
    catatan.add('Ukuran data: ${bytes.length} byte');

    if (mac == null || mac.isEmpty) {
      return HasilCetak(false,
          'Printer belum dipilih. Buka Pengaturan lalu Pilih printer.',
          catatan);
    }

    var izin = await izinSudahAda();
    if (!izin) {
      catatan.add('Izin Bluetooth: belum ada, meminta ke pengguna');
      izin = await mintaIzin();
    }
    catatan.add('Izin Bluetooth: ${izin ? "diberikan" : "DITOLAK"}');
    if (!izin) {
      return HasilCetak(
          false,
          'Izin Bluetooth ditolak. Buka pengaturan aplikasi untuk mengizinkannya.',
          catatan);
    }

    final menyala = await bluetoothAktif();
    catatan.add('Bluetooth HP: ${menyala ? "menyala" : "MATI"}');
    if (!menyala) {
      return HasilCetak(false, 'Bluetooth di HP belum menyala.', catatan);
    }

    if (!await hubungkan(mac, catatan: catatan)) {
      return HasilCetak(
          false,
          'Gagal menyambung setelah 3 percobaan. Pastikan printer menyala, '
          'kertas terpasang, dan tidak sedang dipakai aplikasi lain.',
          catatan);
    }

    if (!await _tulisBertahap(bytes, catatan: catatan)) {
      return HasilCetak(
          false,
          'Sambungan berhasil tapi data ditolak di tengah jalan. '
          'Biasanya kertas habis, atau baterai printer lemah.',
          catatan);
    }

    return HasilCetak(true, 'Struk terkirim ke printer.', catatan);
  }

  /// Susun byte untuk satu nota, sebanyak jumlah salinan yang diatur.
  List<int> susunBytes(Nota nota, {int? paksaSalinan}) {
    final s = Settings.instance;
    final cfg = StrukConfig.dari(s);
    // Urutan: paksaan langsung, lalu setelan nota ini, baru bawaan.
    final jumlah = paksaSalinan ?? nota.jumlahCetak ?? s.jumlahSalinan;

    final semua = <int>[];
    for (var i = 0; i < jumlah; i++) {
      final baris = Struk.render(
        nota,
        cfg,
        salinan: s.labelSalinanKe(i),
        salinanKe: i + 1,
      );
      semua.addAll(EscPos.dariBaris(
        baris,
        barisKosongAkhir: s.barisKosongAkhir,
        potongKertas: s.potongKertas,
        fontKecil: s.fontKecil,
      ));
    }
    return semua;
  }

  /// Seluruh salinan sebagai daftar baris siap cetak, dengan garis
  /// pemisah antar lembar. Dipakai layar pratinjau supaya gaya tiap
  /// baris (tebal, besar, perataan) ikut terlihat.
  List<BarisStruk> susunBaris(Nota nota, {int? paksaSalinan}) {
    final s = Settings.instance;
    final cfg = StrukConfig.dari(s);
    final jumlah = paksaSalinan ?? nota.jumlahCetak ?? s.jumlahSalinan;

    final semua = <BarisStruk>[];
    for (var i = 0; i < jumlah; i++) {
      if (i > 0) {
        semua.add(const BarisStruk(''));
        semua.add(BarisStruk('=' * cfg.lebarKertas));
        semua.add(const BarisStruk(''));
      }
      semua.addAll(Struk.render(
        nota,
        cfg,
        salinan: s.labelSalinanKe(i),
        salinanKe: i + 1,
      ));
    }
    return semua;
  }

  /// Versi teks dari seluruh salinan, untuk pratinjau dan layar debug.
  String susunTeks(Nota nota, {int? paksaSalinan}) {
    final s = Settings.instance;
    final cfg = StrukConfig.dari(s);
    final jumlah = paksaSalinan ?? nota.jumlahCetak ?? s.jumlahSalinan;

    final buf = StringBuffer();
    for (var i = 0; i < jumlah; i++) {
      if (i > 0) buf.writeln('\n${'=' * cfg.lebarKertas}\n');
      final baris = Struk.render(
        nota,
        cfg,
        salinan: s.labelSalinanKe(i),
        salinanKe: i + 1,
      );
      buf.write(Struk.pratinjau(baris, cfg.lebarKertas));
    }
    return buf.toString();
  }

  Future<HasilCetak> cetakNota(Nota nota, {int? paksaSalinan}) async {
    final s = Settings.instance;
    final jumlah = paksaSalinan ?? nota.jumlahCetak ?? s.jumlahSalinan;
    final bytes = susunBytes(nota, paksaSalinan: jumlah);
    final hasil = await kirim(bytes);

    final now = DateTime.now();
    jejakTerakhir = JejakCetak(
      waktu: '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}:'
          '${now.second.toString().padLeft(2, '0')}',
      kodeNota: nota.kode,
      jumlahSalinan: jumlah,
      teksStruk: susunTeks(nota, paksaSalinan: jumlah),
      bytes: bytes,
      hasil: hasil.pesan,
      langkah: hasil.langkah,
    );

    return hasil;
  }
}
