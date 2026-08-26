import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../print/escpos.dart';
import '../print/printer_service.dart';
import '../print/receipt.dart';
import '../store/settings.dart';
import '../ui/umum.dart';
import 'pratinjau.dart';

class PrinterSetupScreen extends StatefulWidget {
  const PrinterSetupScreen({super.key});

  @override
  State<PrinterSetupScreen> createState() => _PrinterSetupScreenState();
}

class _PrinterSetupScreenState extends State<PrinterSetupScreen> {
  final s = Settings.instance;

  DiagnosaPrinter? _diagnosa;
  bool _sibuk = false;
  String _kegiatan = '';

  @override
  void initState() {
    super.initState();
    _periksa(mintaIzin: false);
  }

  // Dilepas lewat variabel, bukan hanya lewat setState, supaya tombol tidak
  // ikut terkunci selamanya kalau layar sudah tidak terpasang.
  void _lepasSibuk() {
    _sibuk = false;
    _kegiatan = '';
    if (mounted) setState(() {});
  }

  Future<void> _periksa({required bool mintaIzin}) async {
    if (_sibuk) return;
    setState(() {
      _sibuk = true;
      _kegiatan = mintaIzin ? 'Meminta izin Bluetooth...' : 'Memeriksa...';
    });
    try {
      final d = await PrinterService.instance.periksa(mintaIzinDulu: mintaIzin);
      if (mounted) setState(() => _diagnosa = d);
    } finally {
      _lepasSibuk();
    }
  }

  Future<void> _pilih(BluetoothInfo b) async {
    await s.setPrinter(b.macAdress, b.name);
    if (!mounted) return;
    setState(() {});
    pesan(context, 'Printer "${b.name}" dipilih.');
  }

  // Lewat pratinjau dulu supaya jelas ini contoh, bukan nota pelanggan.
  Future<void> _tesCetak() async {
    final cfg = StrukConfig.dari(s);
    final l = cfg.lebarKertas;
    // Kelipatan bisa 0 pada kertas sangat sempit, dan operator * menolak
    // bilangan negatif.
    final ulang = (l ~/ 10).clamp(0, 20);
    final baris = <BarisStruk>[
      const BarisStruk('CONTOH', rata: 1, tebal: true, besar: true),
      const BarisStruk('BUKAN STRUK PELANGGAN', rata: 1, tebal: true),
      BarisStruk('-' * l),
      BarisStruk('Lebar kertas: $l karakter'),
      BarisStruk('1234567890' * ulang),
      const BarisStruk('Rata kiri'),
      const BarisStruk('Rata tengah', rata: 1),
      const BarisStruk('Rata kanan', rata: 2),
      const BarisStruk('[B] huruf tebal', tebal: true),
      const BarisStruk('[H] besar', besar: true),
      const BarisStruk('[BH] tebal', tebal: true, besar: true),
      BarisStruk('-' * l),
      const BarisStruk('Angka di atas harus pas', rata: 1),
      const BarisStruk('satu baris penuh.', rata: 1),
    ];
    final lanjut = await tampilkanPratinjauBaris(
      context,
      baris,
      judul: 'Ini Contoh, Bukan Struk',
      keterangan: 'Halaman uji untuk memeriksa printer. '
          'Isinya bukan nota pelanggan. Untuk mencetak struk sungguhan, '
          'buka notanya lalu tekan Cetak Struk di sana.',
      labelCetak: 'Cetak Contoh',
      warnaJudul: Colors.orange.shade900,
    );
    if (!lanjut || !mounted) return;

    setState(() {
      _sibuk = true;
      _kegiatan = 'Mengirim tes cetak...';
    });

    final HasilCetak hasil;
    try {
      final bytes = EscPos.dariBaris(baris,
          barisKosongAkhir: s.barisKosongAkhir,
          potongKertas: s.potongKertas,
          fontKecil: s.fontKecil);
      hasil = await PrinterService.instance.kirim(bytes);
    } finally {
      _lepasSibuk();
    }
    if (!mounted) return;

    if (hasil.sukses) {
      pesan(context, hasil.pesan);
      return;
    }

    // Kalau gagal, tampilkan catatan tiap langkah supaya kelihatan
    // berhenti di tahap mana, bukan cuma "gagal".
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cetak Gagal'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(hasil.pesan),
              const SizedBox(height: 14),
              const Text('Rincian langkah:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              KotakKode(hasil.rincian),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        ],
      ),
    );
  }

  bool get _siapTes => s.printerMac != null && s.printerMac!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final d = _diagnosa;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Printer Thermal'),
        actions: [
          IconButton(
            onPressed: _sibuk ? null : () => _periksa(mintaIzin: false),
            icon: const Icon(Icons.refresh),
            tooltip: 'Segarkan',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          if (_sibuk) const LinearProgressIndicator(minHeight: 3),
          if (_sibuk)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(_kegiatan,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
          const SizedBox(height: 12),

          if (d != null) _kartuStatus(d),

          if (d != null && !d.izinDiberikan)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  FilledButton.icon(
                    onPressed: _sibuk ? null : () => _periksa(mintaIzin: true),
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Izinkan Bluetooth'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _sibuk
                        ? null
                        : () =>
                            PrinterService.instance.bukaPengaturanAplikasi(),
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Buka Pengaturan Aplikasi'),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48)),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Kalau tombol Izinkan tidak memunculkan dialog, berarti '
                      'izinnya pernah ditolak permanen. Buka Pengaturan '
                      'Aplikasi, masuk ke Izin, lalu aktifkan Perangkat di '
                      'sekitar (atau Lokasi pada Android 11 ke bawah).',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),

          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Printer harus sudah dipasangkan lewat Pengaturan Bluetooth '
              'bawaan HP. Aplikasi ini hanya menampilkan perangkat yang sudah '
              'terpasang, tidak melakukan pemindaian sendiri.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),

          if (s.printerMac != null)
            ListTile(
              leading: const Icon(Icons.print, color: Colors.green),
              title: Text(s.printerNama ?? '-'),
              subtitle: Text('Terpilih  -  ${s.printerMac}'),
              trailing: TextButton(
                onPressed: () async {
                  await s.lupakanPrinter();
                  await PrinterService.instance.putuskan();
                  if (mounted) setState(() {});
                },
                child: const Text('Lupakan'),
              ),
            ),

          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Perangkat terpasang',
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),

          if (d == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (d.perangkat.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(d.catatan,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey)),
              ),
            )
          else
            ...d.perangkat.map(
              (b) => ListTile(
                leading: const Icon(Icons.bluetooth),
                title: Text(b.name.isEmpty ? '(tanpa nama)' : b.name),
                subtitle: Text(b.macAdress),
                trailing: s.printerMac == b.macAdress
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                onTap: () => _pilih(b),
              ),
            ),

          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              onPressed: (_sibuk || !_siapTes) ? null : _tesCetak,
              icon: const Icon(Icons.print_outlined),
              label: const Text('Tes Cetak Contoh'),
            ),
          ),
          if (!_siapTes)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Pilih printer dulu sebelum bisa tes cetak.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _kartuStatus(DiagnosaPrinter d) {
    Widget baris(String label, bool ok, String nilai) => Row(
          children: [
            Icon(ok ? Icons.check_circle : Icons.cancel,
                size: 16,
                color: ok ? Colors.green.shade700 : Colors.red.shade700),
            const SizedBox(width: 8),
            Expanded(child: BarisNilai(label, nilai, tebal: true)),
          ],
        );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Status',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          baris('Izin Bluetooth', d.izinDiberikan,
              d.izinDiberikan ? 'Diberikan' : 'Belum ada'),
          baris('Bluetooth HP', d.bluetoothMenyala,
              d.bluetoothMenyala ? 'Menyala' : 'Mati'),
          baris('Perangkat terpasang', d.perangkat.isNotEmpty,
              '${d.perangkat.length}'),
          const SizedBox(height: 6),
          Text(d.catatan, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
