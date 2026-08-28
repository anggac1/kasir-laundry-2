import 'dart:async';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../models/models.dart';
import '../store/settings.dart';
import 'escpos.dart';
import 'receipt.dart';

class HasilCetak {
  final bool sukses;
  final String pesan;

  // Catatan tiap langkah, ditampilkan kalau gagal.
  final List<String> langkah;

  const HasilCetak(this.sukses, this.pesan, [this.langkah = const []]);

  String get rincian => langkah.join('\n');
}

// Keadaan Bluetooth, dipakai layar printer untuk menjelaskan apa yang salah.
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

// Printer thermal Bluetooth Classic (SPP), disetel untuk printer 58mm
// murah seperti RPP02N yang punya dua kebiasaan merepotkan: menolak
// kiriman besar sekaligus, dan melaporkan masih tersambung padahal
// soketnya sudah mati.
//
// Setiap panggilan ke lapisan Android dibatasi waktunya. Tanpa itu, satu
// panggilan yang menggantung membuat layar berputar selamanya karena
// Future-nya tidak pernah selesai dan juga tidak melempar error.
class PrinterService {
  PrinterService._();
  static final PrinterService instance = PrinterService._();

  static const _batas = Duration(seconds: 8);
  static const _batasSambung = Duration(seconds: 12);
  static const _batasIzin = Duration(seconds: 25);

  // Printer SPP murah punya buffer kecil; kiriman besar sekaligus sering
  // diterima separuh lalu berhenti.
  static const _ukuranPotongan = 512;

  // Batas keseluruhan pengiriman, supaya struk panjang di printer yang
  // lambat tidak menahan layar tanpa ujung.
  static const _batasTotalKirim = Duration(seconds: 45);

  // Bungkus semua panggilan plugin: apa pun yang terjadi, selesai.
  Future<T> _aman<T>(
    Future<T> Function() jalankan,
    T cadangan, {
    Duration batas = _batas,
    List<String>? catatan,
    String? label,
  }) async {
    try {
      return await jalankan().timeout(batas);
    } on TimeoutException {
      if (label != null) catatan?.add('$label: tidak menjawab dalam ${batas.inSeconds} detik');
      return cadangan;
    } catch (e) {
      if (label != null) catatan?.add('$label: gagal ($e)');
      return cadangan;
    }
  }

  Future<PermissionStatus> _izin(
    Permission p, {
    required bool minta,
  }) =>
      _aman(
        () => minta ? p.request() : p.status,
        PermissionStatus.denied,
        batas: minta ? _batasIzin : const Duration(seconds: 4),
      );

  // Android 12+ memakai BLUETOOTH_CONNECT dan BLUETOOTH_SCAN, Android 11
  // ke bawah memakai izin lokasi. Izin yang tidak berlaku di versi
  // tertentu langsung ditolak sistem, dan itu normal.
  Future<bool> _periksaIzin({required bool minta}) async {
    final connect = await _izin(Permission.bluetoothConnect, minta: minta);
    if (connect.isGranted) {
      if (minta) await _izin(Permission.bluetoothScan, minta: true);
      return true;
    }
    final lokasi = await _izin(Permission.location, minta: minta);
    return lokasi.isGranted;
  }

  Future<bool> mintaIzin() => _periksaIzin(minta: true);

  Future<bool> izinSudahAda() => _periksaIzin(minta: false);

  Future<void> bukaPengaturanAplikasi() =>
      _aman(() => openAppSettings(), false);

  // Buka layar Setelan Bluetooth di HP.
  //
  // Memakai MethodChannel bawaan Flutter, bukan paket tambahan. Sisi
  // Android-nya dipasang oleh kode di android_overrides/MainActivity.kt,
  // yang disalin GitHub Actions ke dalam kerangka proyek saat build.
  //
  // Mengembalikan false bila saluran itu tidak menjawab, supaya layar
  // pemanggil bisa menampilkan petunjuk manual sebagai gantinya.
  Future<bool> bukaSetelanBluetooth() {
    const saluran = MethodChannel('kasir_laundry/setelan');
    return _aman(
      () async {
        await saluran.invokeMethod<void>('bukaSetelanBluetooth');
        return true;
      },
      false,
      batas: const Duration(seconds: 5),
    );
  }

  Future<bool> bluetoothAktif() =>
      _aman(() => PrintBluetoothThermal.bluetoothEnabled, false);

  Future<List<BluetoothInfo>> daftarPrinter() =>
      _aman(() => PrintBluetoothThermal.pairedBluetooths, <BluetoothInfo>[]);

  Future<void> putuskan() =>
      _aman(() => PrintBluetoothThermal.disconnect, false);

  // Sambungan lama selalu diputus dulu: RPP02N kadang melaporkan masih
  // tersambung padahal soketnya sudah mati sejak printer dimatikan, dan
  // menulis ke soket mati gagal tanpa pesan apa pun.
  Future<bool> hubungkan(String mac, {List<String>? catatan}) async {
    for (var percobaan = 1; percobaan <= 3; percobaan++) {
      await putuskan();
      await Future.delayed(const Duration(milliseconds: 300));

      final ok = await _aman(
        () => PrintBluetoothThermal.connect(macPrinterAddress: mac),
        false,
        batas: _batasSambung,
        catatan: catatan,
        label: 'Sambung percobaan $percobaan',
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

  // Dikirim sepotong-sepotong karena buffer printer hanya beberapa ratus
  // byte, sedangkan struk dua salinan bisa lebih dari 2 KB.
  Future<bool> _tulisBertahap(List<int> bytes, {List<String>? catatan}) async {
    final mulai = DateTime.now();
    var terkirim = 0;

    for (var i = 0; i < bytes.length; i += _ukuranPotongan) {
      if (DateTime.now().difference(mulai) > _batasTotalKirim) {
        catatan?.add('Kirim data: melewati batas waktu di byte ke-$terkirim '
            'dari ${bytes.length}');
        return false;
      }

      final akhir = (i + _ukuranPotongan).clamp(0, bytes.length);
      final ok = await _aman(
        () => PrintBluetoothThermal.writeBytes(bytes.sublist(i, akhir)),
        false,
        batas: _batasSambung,
      );

      if (!ok) {
        catatan?.add(
            'Kirim data: gagal di byte ke-$terkirim dari ${bytes.length}');
        return false;
      }

      terkirim = akhir;
      // Jeda kecil supaya buffer printer sempat kosong.
      await Future.delayed(const Duration(milliseconds: 20));
    }

    catatan?.add('Kirim data: berhasil ($terkirim byte)');
    return true;
  }

  // Kumpulkan keadaan dalam satu panggilan. Selalu selesai, walau bisa
  // memakan waktu bila dialog izin sistem ikut ditunggu.
  Future<DiagnosaPrinter> periksa({bool mintaIzinDulu = false}) async {
    var izin = await izinSudahAda();
    if (!izin && mintaIzinDulu) izin = await mintaIzin();

    final menyala = await bluetoothAktif();
    final perangkat = izin ? await daftarPrinter() : <BluetoothInfo>[];

    final String catatan;
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

  // Tiap langkah dicatat supaya kalau gagal terlihat berhenti di tahap mana.
  Future<HasilCetak> kirim(List<int> bytes) async {
    final s = Settings.instance;
    final catatan = <String>[];
    final mac = s.printerMac;

    catatan.add('Printer tersimpan: ${s.printerNama ?? "-"} '
        '(${mac ?? "belum dipilih"})');
    catatan.add('Ukuran data: ${bytes.length} byte');

    if (mac == null || mac.isEmpty) {
      return HasilCetak(false,
          'Printer belum dipilih. Buka Pengaturan lalu Pilih printer.', catatan);
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
          'Izin Bluetooth ditolak. Buka pengaturan aplikasi untuk '
          'mengizinkannya.',
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

  // Urutan: paksaan langsung, lalu setelan nota ini, baru bawaan.
  int jumlahSalinan(Nota nota, [int? paksa]) =>
      paksa ?? nota.jumlahCetak ?? Settings.instance.jumlahSalinan;

  // Semua salinan sebagai baris siap cetak, dengan pemisah antar lembar.
  // Satu-satunya tempat salinan dirangkai; bytes dan teks ikut dari sini.
  List<BarisStruk> susunBaris(Nota nota, {int? paksaSalinan}) {
    final s = Settings.instance;
    final cfg = StrukConfig.dari(s);
    final jumlah = jumlahSalinan(nota, paksaSalinan);

    final semua = <BarisStruk>[];
    for (var i = 0; i < jumlah; i++) {
      if (i > 0) {
        semua
          ..add(const BarisStruk(''))
          ..add(BarisStruk('=' * cfg.lebarKertas))
          ..add(const BarisStruk(''));
      }
      semua.addAll(Struk.render(nota, cfg,
          salinan: s.labelSalinanKe(i), salinanKe: i + 1));
    }
    return semua;
  }

  List<int> susunBytes(Nota nota, {int? paksaSalinan}) {
    final s = Settings.instance;
    final cfg = StrukConfig.dari(s);
    final jumlah = jumlahSalinan(nota, paksaSalinan);

    final semua = <int>[];
    for (var i = 0; i < jumlah; i++) {
      final baris = Struk.render(nota, cfg,
          salinan: s.labelSalinanKe(i), salinanKe: i + 1);
      semua.addAll(EscPos.dariBaris(
        baris,
        barisKosongAkhir: s.barisKosongAkhir,
        potongKertas: s.potongKertas,
        fontKecil: s.fontKecil,
      ));
    }
    return semua;
  }

  Future<HasilCetak> cetakNota(Nota nota, {int? paksaSalinan}) =>
      kirim(susunBytes(nota, paksaSalinan: paksaSalinan));
}
