// Format angka dan tanggal. Manual, tanpa paket intl, agar build ringan.

String _2(int v) => v.toString().padLeft(2, '0');

// 1500000 -> "Rp1.500.000"
String rupiah(num value) {
  final n = value.round();
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '${n < 0 ? '-' : ''}Rp$buf';
}

String tanggal(DateTime d) => '${_2(d.day)}/${_2(d.month)}/${d.year}';

String jam(DateTime d) => '${_2(d.hour)}:${_2(d.minute)}';

String jamDetik(DateTime d) => '${jam(d)}:${_2(d.second)}';

String tanggalJam(DateTime d) => '${tanggal(d)} ${jam(d)}';

const _namaHari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

String hari(DateTime d) => _namaHari[(d.weekday - 1) % 7];

// Hex dump gaya "offset  bytes  teks", 16 byte per baris.
String hex(List<int> bytes) {
  final buf = StringBuffer();
  for (var i = 0; i < bytes.length; i += 16) {
    final akhir = (i + 16 > bytes.length) ? bytes.length : i + 16;
    final potong = bytes.sublist(i, akhir);
    final kolomHex = potong
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
    final teks = potong
        .map((b) => (b >= 32 && b < 127) ? String.fromCharCode(b) : '.')
        .join();
    buf.writeln('${i.toRadixString(16).padLeft(4, '0')}  '
        '${kolomHex.padRight(47)}  $teks');
  }
  return buf.toString();
}

// Buang desimal bila bulat: 3 kg, bukan 3.00 kg.
String qtyStr(double q) {
  if (q == q.roundToDouble()) return q.round().toString();
  return q
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
